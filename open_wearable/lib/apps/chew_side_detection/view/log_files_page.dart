import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../controller/logger.dart';

class LogFilesPage extends StatefulWidget {
  const LogFilesPage({super.key});

  @override
  State<LogFilesPage> createState() => _LogFilesPageState();
}

class _LogFilesPageState extends State<LogFilesPage> {
  List<File> _logFiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Multi-selection state
  bool _selectionMode = false;
  final Set<File> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final files = await ExperimentLogger.getAllLogFiles();

      setState(() {
        _logFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading log files: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _shareFiles(List<File> files) async {
    try {
      final xFiles = files.map((f) => XFile(f.path)).toList();
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Experiment Logs',
          files: xFiles,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(File file) async {
    try {
      await ExperimentLogger.deleteLogFile(file);
      _selectedFiles.remove(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedFiles() async {
    final confirmed = await showPlatformDialog<bool>(
      context: context,
      builder: (context) => PlatformAlertDialog(
        title: Text('Delete Selected Files'),
        content: Text(
          'Are you sure you want to delete ${_selectedFiles.length} selected file(s)? This action cannot be undone.',
        ),
        actions: [
          PlatformDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PlatformDialogAction(
            child: Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (var file in _selectedFiles.toList()) {
        await _deleteFile(file);
      }
      await _loadLogFiles();
      _clearSelection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected files deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _getFileDisplayName(File file) => file.path.split('/').last;

  String _getFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getFileDate(File file) {
    try {
      final date = file.lastModifiedSync();
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  void _toggleSelection(File file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
      } else {
        _selectedFiles.add(file);
      }
      _selectionMode = _selectedFiles.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
      _selectionMode = false;
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedFiles.length == _logFiles.length) {
        _selectedFiles.clear();
        _selectionMode = false;
      } else {
        _selectedFiles.addAll(_logFiles);
        _selectionMode = true;
      }
    });
  }

  Widget _buildPopupMenu(File file) {
    return PopupMenuButton(
      icon: Icon(Icons.more_vert),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 20),
              SizedBox(width: 8),
              Text('Share'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'share':
            _shareFiles([file]);
            break;
          case 'delete':
            _deleteFile(file);
            _loadLogFiles();
            break;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(
            _selectionMode ? '${_selectedFiles.length} selected' : 'Log Files'),
        trailingActions: [
          if (_selectionMode) ...[
            PlatformIconButton(
              icon: Icon(Icons.select_all),
              onPressed: _selectAll,
            ),
            PlatformIconButton(
              icon: Icon(Icons.clear),
              onPressed: _clearSelection,
            ),
          ] else
            PlatformIconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadLogFiles,
            ),
        ],
      ),
      body: _buildBody(),
      material: (_, __) => MaterialScaffoldData(
        floatingActionButton: _selectionMode
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'shareBtn',
                    onPressed: () {
                      if (_selectedFiles.isNotEmpty) {
                        _shareFiles(_selectedFiles.toList());
                      }
                    },
                    child: Icon(Icons.share),
                  ),
                  SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'deleteBtn',
                    backgroundColor: Colors.red,
                    onPressed: _deleteSelectedFiles,
                    child: Icon(Icons.delete),
                  ),
                ],
              )
            : null,
      ),
      cupertino: (_, __) => CupertinoPageScaffoldData(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading log files...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Error Loading Files',
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            SizedBox(height: 24),
            PlatformElevatedButton(
              onPressed: _loadLogFiles,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_logFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Log Files Found',
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 8),
            Text('Run some timed experiments to generate log files.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 24),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _logFiles.length,
      itemBuilder: (context, index) {
        final file = _logFiles[index];
        final isSelected = _selectedFiles.contains(file);

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: _selectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(file),
                  )
                : Icon(Icons.description, color: Colors.grey),
            title: Text(_getFileDisplayName(file)),
            subtitle: Text(
                'Size: ${_getFileSize(file)} • Modified: ${_getFileDate(file)}'),
            onTap: _selectionMode
                ? () => _toggleSelection(file)
                : null, // could open file in future
            onLongPress: () => _toggleSelection(file),
            trailing: !_selectionMode ? _buildPopupMenu(file) : null,
          ),
        );
      },
    );
  }
}
