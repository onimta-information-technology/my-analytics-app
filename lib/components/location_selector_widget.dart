import 'package:flutter/material.dart';
import 'package:ballys_reservation_app/data/services/device_config_service.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class LocationSelectorWidget extends StatefulWidget {
  final VoidCallback onLocationChanged;

  const LocationSelectorWidget({
    super.key,
    required this.onLocationChanged,
  });

  @override
  State<LocationSelectorWidget> createState() => _LocationSelectorWidgetState();
}

class _LocationSelectorWidgetState extends State<LocationSelectorWidget> {
  LocationConfig? _currentLocation;
  List<LocationConfig> _locations = [];
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    try {
      final isAdmin = await StorageUtil.isAdmin();
      final currentLocation = await StorageUtil.getCurrentLocation();
      
      if (isAdmin) {
        final locations = await StorageUtil.getLocations();
        if (mounted) {
          setState(() {
            _isAdmin = isAdmin;
            _currentLocation = currentLocation;
            _locations = locations;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _currentLocation = currentLocation;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showLocationSelector() async {
    final result = await showModalBottomSheet<LocationConfig>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Location',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _locations.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final location = _locations[index];
                  final isSelected = location.code == _currentLocation?.code;
                  
                  return Card(
                    elevation: isSelected ? 4 : 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.orange : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.orange.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // child: Icon(
                        //   Icons.business,
                        //   color: isSelected ? Colors.orange : Colors.grey[600],
                        // ),
                        child: ClipRRect(
  borderRadius: BorderRadius.circular(6),
  child: location.imageUrl != null &&
          location.imageUrl!.isNotEmpty
      ? Image.network(
          location.imageUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.business),
        )
      : const Icon(Icons.business),
),

                      ),
                      title: Text(
                        location.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.orange : Colors.black,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            location.code,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: location.isEnabled
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              location.isEnabled ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                color: location.isEnabled
                                    ? Colors.green[700]
                                    : Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.orange,
                              size: 28,
                            )
                          : null,
                      enabled: location.isEnabled,
                      onTap: location.isEnabled
                          ? () {
                              // Return the selected location to close the bottom sheet
                              Navigator.pop(context, location);
                            }
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    // Handle the result after bottom sheet is fully closed
    if (result != null && mounted) {
      await _changeLocation(result);
    }
  }

  Future<void> _changeLocation(LocationConfig location) async {
    if (!mounted) return;
    
    // Don't show dialog in the context that's closing
    // Use root navigator context
    final navigatorContext = Navigator.of(context, rootNavigator: true).context;
    
    try {
      // Show loading overlay
      showDialog(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false,
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Switching location...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await DeviceConfigService.changeLocation(location);

      if (mounted) {
        setState(() {
          _currentLocation = location;
        });

        // Close loading dialog using root navigator
        Navigator.of(navigatorContext, rootNavigator: true).pop();
        
        // Wait a frame before showing snackbar
        await Future.delayed(const Duration(milliseconds: 50));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched to ${location.name}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Wait for UI to settle before triggering callback
          await Future.delayed(const Duration(milliseconds: 300));
          
          if (mounted) {
            widget.onLocationChanged();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(navigatorContext, rootNavigator: true).pop();
        
        await Future.delayed(const Duration(milliseconds: 50));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to switch location: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (!_isAdmin || _currentLocation == null) {
      return const SizedBox.shrink();
    }

  //   return GestureDetector(
  //     onTap: _showLocationSelector,
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //       decoration: BoxDecoration(
  //         color: Colors.orange.withOpacity(0.1),
  //         borderRadius: BorderRadius.circular(20),
  //         border: Border.all(color: Colors.orange, width: 1.5),
  //       ),
  //       child: Row(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           const Icon(Icons.location_on, size: 16, color: Color.fromARGB(255, 0, 0, 0)),
  //           const SizedBox(width: 6),
  //           ConstrainedBox(
  //             constraints: const BoxConstraints(maxWidth: 150),
  //             child: Text(
  //               _currentLocation!.name,
  //               style: const TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.bold,
  //                 color: Color.fromARGB(255, 0, 0, 0),
  //               ),
  //               overflow: TextOverflow.ellipsis,
  //             ),
  //           ),
  //           const SizedBox(width: 6),
  //           const Icon(Icons.arrow_drop_down, size: 22, color: Color.fromARGB(255, 0, 0, 0)),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  return GestureDetector(
  onTap: _showLocationSelector,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.orange, width: 1.5),
    ),
    child: Row(
      children: [
        // LEFT ICON
        const Icon(
          Icons.location_on,
          size: 16,
          color: Colors.black,
        ),

        // CENTER TEXT
        Expanded(
          child: Center(
            child: Text(
              _currentLocation!.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),

        // RIGHT ICON
        const Icon(
          Icons.arrow_drop_down,
          size: 22,
          color: Colors.black,
        ),
      ],
    ),
  ),
);

  }
}