import 'package:flutter/material.dart';

class TrackingButton extends StatelessWidget {
  final bool isTracking;
  final VoidCallback onPressed;

  const TrackingButton({
    Key? key,
    required this.isTracking,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isTracking
                ? [
                    const Color.fromARGB(255, 235, 235, 235),
                    const Color.fromARGB(179, 241, 241, 241)
                  ]
                : [
                    const Color.fromARGB(255, 253, 253, 253),
                    const Color.fromARGB(255, 241, 241, 241)
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isTracking ? Icons.stop : Icons.play_arrow,
          color: const Color.fromARGB(255, 44, 44, 44),
          size: 36,
        ),
      ),
    );
  }
}
