import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

typedef OnFilesDropped = Future<void> Function(List<String> filePaths);

class DragDropZone extends StatefulWidget {
  final Widget child;
  final OnFilesDropped onFilesDropped;
  final bool enabled;

  const DragDropZone({
    Key? key,
    required this.child,
    required this.onFilesDropped,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<DragDropZone> createState() => _DragDropZoneState();
}

class _DragDropZoneState extends State<DragDropZone> {
  bool _isDraggingOver = false;

  @override
  Widget build(BuildContext context) {
    
    if (kIsWeb || !widget.enabled) {
      return widget.child;
    }

    return DropTarget(
      onDragDone: (detail) async {
        setState(() => _isDraggingOver = false);
        
        final filePaths = <String>[];
        for (final file in detail.files) {
          final path = file.path;
          
          if (await File(path).exists()) {
            filePaths.add(path);
          }
        }

        if (filePaths.isNotEmpty) {
          await widget.onFilesDropped(filePaths);
        }
      },
      onDragEntered: (detail) {
        setState(() => _isDraggingOver = true);
      },
      onDragExited: (detail) {
        setState(() => _isDraggingOver = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: _isDraggingOver
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
          color: _isDraggingOver
              ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
              : null,
          borderRadius: _isDraggingOver ? BorderRadius.circular(12) : null,
        ),
        child: widget.child,
      ),
    );
  }
}