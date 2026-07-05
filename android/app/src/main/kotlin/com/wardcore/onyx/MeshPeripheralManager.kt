package com.wardcore.onyx

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MeshPeripheralManager(private val context: Context) : EventChannel.StreamHandler {

    companion object {
        private const val TAG = "MeshPeripheral"
        private val MESH_SERVICE_UUID = UUID.fromString("4f4e5958-4d45-5348-0000-000000000001")
        private val IDENTITY_CHAR_UUID = UUID.fromString("4f4e5958-4d45-5348-0000-000000000002")
        private val INBOX_CHAR_UUID    = UUID.fromString("4f4e5958-4d45-5348-0000-000000000003")
        private val CLIENT_CONFIG_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val adapter: BluetoothAdapter? get() = bluetoothManager.adapter

    private var gattServer: BluetoothGattServer? = null
    private var advCallback: AdvertiseCallback? = null
    private var identityBytes: ByteArray = ByteArray(0)
    private var eventSink: EventChannel.EventSink? = null

    // Called once the GATT service is registered and advertising can safely start.
    private var onServiceReady: (() -> Unit)? = null

    fun start(identity: ByteArray, result: MethodChannel.Result) {
        // Always clean up before restarting — prevents GATT server leaks and
        // ADVERTISE_FAILED_TOO_MANY_ADVERTISERS when start() is called repeatedly
        // (e.g. BT re-enable, account switch).
        stop()
        identityBytes = identity
        try {
            startGattServer()
            result.success(null)
            Log.d(TAG, "started, identity=${identity.size} bytes")
        } catch (e: Exception) {
            Log.e(TAG, "start failed: $e")
            result.error("MESH_PERIPHERAL_ERROR", e.message, null)
        }
    }

    fun stop() {
        onServiceReady = null
        try {
            adapter?.bluetoothLeAdvertiser?.stopAdvertising(advCallback)
        } catch (_: Exception) {}
        advCallback = null

        gattServer?.close()
        gattServer = null
        Log.d(TAG, "stopped")
    }

    private fun startGattServer() {
        val identityChar = BluetoothGattCharacteristic(
            IDENTITY_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        val cccd = BluetoothGattDescriptor(
            CLIENT_CONFIG_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        val inboxChar = BluetoothGattCharacteristic(
            INBOX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or
                    BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        inboxChar.addDescriptor(cccd)

        val service = BluetoothGattService(
            MESH_SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )
        service.addCharacteristic(identityChar)
        service.addCharacteristic(inboxChar)

        // Start advertising only after the service is actually registered.
        // addService() is async — advertising before onServiceAdded fires means
        // a connecting central may call discoverServices() and get an empty list.
        onServiceReady = { startAdvertising() }

        gattServer = bluetoothManager.openGattServer(context, object : BluetoothGattServerCallback() {

            override fun onServiceAdded(status: Int, svc: BluetoothGattService) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(TAG, "GATT service registered — starting advertising")
                    mainHandler.post { onServiceReady?.invoke() }
                } else {
                    Log.e(TAG, "GATT addService failed status=$status")
                }
            }

            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                Log.d(TAG, "connection ${device.address} -> state=$newState")
            }

            override fun onCharacteristicReadRequest(
                device: BluetoothDevice, requestId: Int, offset: Int,
                characteristic: BluetoothGattCharacteristic
            ) {
                if (characteristic.uuid == IDENTITY_CHAR_UUID) {
                    val slice = if (offset < identityBytes.size)
                        identityBytes.copyOfRange(offset, identityBytes.size)
                    else
                        ByteArray(0)
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, slice)
                } else {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
                }
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice, requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean, responseNeeded: Boolean,
                offset: Int, value: ByteArray
            ) {
                if (characteristic.uuid == INBOX_CHAR_UUID) {
                    val copy = value.copyOf()
                    // Prepend sender MAC so Flutter can add a reverse neighbor entry:
                    // byte[0] = addr length, byte[1..addrLen] = MAC string, rest = packet
                    val addrBytes = device.address.toByteArray(Charsets.US_ASCII)
                    val combined = ByteArray(1 + addrBytes.size + copy.size)
                    combined[0] = addrBytes.size.toByte()
                    addrBytes.copyInto(combined, 1)
                    copy.copyInto(combined, 1 + addrBytes.size)
                    mainHandler.post { eventSink?.success(combined) }
                }
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice, requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean, responseNeeded: Boolean,
                offset: Int, value: ByteArray
            ) {
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }
            }
        })

        if (gattServer == null) throw Exception("openGattServer returned null — BT may be off")
        gattServer?.addService(service)
        Log.d(TAG, "GATT server open, waiting for service registration...")
    }

    private fun startAdvertising() {
        val leAdvertiser = adapter?.bluetoothLeAdvertiser
        if (leAdvertiser == null) {
            Log.w(TAG, "BLE advertising not supported on this device")
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()

        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(MESH_SERVICE_UUID))
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .build()

        advCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                Log.d(TAG, "advertising started")
            }
            override fun onStartFailure(errorCode: Int) {
                Log.e(TAG, "advertising failed errorCode=$errorCode")
            }
        }

        leAdvertiser.startAdvertising(settings, data, advCallback)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
