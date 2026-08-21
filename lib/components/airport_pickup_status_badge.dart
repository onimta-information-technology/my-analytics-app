import 'package:ballys_reservation_app/models/transport/transport_reservation.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';

/// Look and feel for `airport_pickup_status`, shared by the transport list and
/// the transport view so a stage always reads the same colour everywhere.
extension AirportPickupStatusStyle on AirportPickupStatus {
  Color get color {
    switch (this) {
      case AirportPickupStatus.noted:
        return Colors.orange.shade700;
      case AirportPickupStatus.accepted:
        return Colors.blue.shade700;
      case AirportPickupStatus.acknowledged:
        return Colors.green.shade700;
    }
  }

  IconData get icon {
    switch (this) {
      case AirportPickupStatus.noted:
        return Icons.edit_note;
      case AirportPickupStatus.accepted:
        return Icons.check_circle_outline;
      case AirportPickupStatus.acknowledged:
        return Icons.verified_outlined;
    }
  }
}

/// Pill showing that a request is an airport pickup and how far transport
/// staff have taken it. [status] is null while nothing has been reported yet,
/// which shows the plain "Airport Pickup" pill.
class AirportPickupStatusBadge extends StatelessWidget {
  const AirportPickupStatusBadge({
    super.key,
    required this.status,
    required this.fontSettings,
    this.compact = false,
  });

  final AirportPickupStatus? status;
  final FontSettings fontSettings;

  /// Drops the "Airport Pickup" prefix, for rows that are already tight.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stage = status;
    final color = stage?.color ?? Colors.blueGrey.shade600;
    final label = stage == null
        ? 'Airport Pickup'
        : (compact ? stage.label : 'Airport Pickup · ${stage.label}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stage?.icon ?? Icons.flight_land, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSettings.fontSize,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
