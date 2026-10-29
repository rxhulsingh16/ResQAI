import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

enum SosButtonMode { pill, circle }

class InteractiveSosButton extends StatefulWidget {
  final Future<void> Function() onTriggered;
  final VoidCallback? onCancel;
  final bool isSubmitting;
  final String? activeIncidentId;
  final SosButtonMode mode;
  final double? height;
  final double? width;
  final String localityName;

  const InteractiveSosButton({
    super.key,
    required this.onTriggered,
    this.onCancel,
    this.isSubmitting = false,
    this.activeIncidentId,
    this.mode = SosButtonMode.pill,
    this.height,
    this.width,
    this.localityName = 'Current Location',
  });

  @override
  State<InteractiveSosButton> createState() => _InteractiveSosButtonState();
}

class _InteractiveSosButtonState extends State<InteractiveSosButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  // Hold-to-activate progress
  late AnimationController _holdController;
  bool _isHolding = false;

  // Tap-to-arm state
  bool _isArmed = false;
  int _remainingSeconds = 5;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // 2.0s hold
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onHoldCompleted();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _holdController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onHoldStart() {
    if (widget.isSubmitting || widget.activeIncidentId != null) return;
    setState(() {
      _isHolding = true;
      _isArmed = false;
    });
    _countdownTimer?.cancel();
    HapticFeedback.heavyImpact();
    _holdController.forward(from: 0.0);
  }

  void _onHoldEnd() {
    if (!_isHolding) return;
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
      setState(() => _isHolding = false);
    }
  }

  void _onHoldCompleted() {
    setState(() => _isHolding = false);
    HapticFeedback.vibrate();
    widget.onTriggered();
  }

  void _onQuickTap() {
    if (widget.isSubmitting || widget.activeIncidentId != null) return;

    if (!_isArmed) {
      // First tap arms the button for 5 seconds
      HapticFeedback.mediumImpact();
      setState(() {
        _isArmed = true;
        _remainingSeconds = 5;
      });

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_remainingSeconds > 1) {
          setState(() => _remainingSeconds--);
          HapticFeedback.selectionClick();
        } else {
          timer.cancel();
          setState(() {
            _isArmed = false;
            _remainingSeconds = 5;
          });
        }
      });
    } else {
      // Second tap confirms emergency dispatch
      _countdownTimer?.cancel();
      setState(() => _isArmed = false);
      HapticFeedback.vibrate();
      widget.onTriggered();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeIncidentId != null) {
      return _buildActiveDispatchedState();
    }

    if (widget.mode == SosButtonMode.circle) {
      return _buildCircularButton();
    }
    return _buildPillButton();
  }

  // 1. ACTIVE DISPATCHED STATE CARD
  Widget _buildActiveDispatchedState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF87171), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency, color: Color(0xFFDC2626), size: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      '🚨 SOS DISPATCHED TO EOC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.yellowAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Case: ${widget.activeIncidentId} • ${widget.localityName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const Text(
                  'NDRF Boat Unit 4 & Goonj NGO Alerted',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (widget.onCancel != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: widget.onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                backgroundColor: Colors.black26,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  // 2. PILL BUTTON (FOR DASHBOARDS)
  Widget _buildPillButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _holdController]),
      builder: (context, _) {
        final scale = (_isArmed || _isHolding) ? _pulseAnimation.value : 1.0;
        final holdProgress = _holdController.value;

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTapDown: (_) => _onHoldStart(),
            onTapUp: (_) => _onHoldEnd(),
            onTapCancel: () => _onHoldEnd(),
            onTap: () {
              if (holdProgress < 0.2) {
                _onQuickTap();
              }
            },
            child: Container(
              height: widget.height ?? 68,
              decoration: BoxDecoration(
                gradient: _isArmed
                    ? const LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [AppColors.primaryRed, AppColors.primaryRed],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isArmed
                      ? Colors.yellowAccent
                      : (_isHolding ? Colors.white : Colors.white.withOpacity(0.3)),
                  width: _isArmed ? 2.5 : (_isHolding ? 2.0 : 1.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isArmed ? Colors.red : AppColors.primaryRed).withOpacity(0.45),
                    blurRadius: _isArmed ? 16 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Hold Progress Fill Layer (Left to Right)
                  if (_isHolding)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: holdProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.28),
                        ),
                      ),
                    ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Beacon Icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: widget.isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _isArmed ? Icons.warning_amber : Icons.emergency,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Prompt
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isHolding
                                    ? 'HOLDING... ${(2.0 - holdProgress * 2.0).toStringAsFixed(1)}s'
                                    : (_isArmed
                                        ? 'CONFIRM SOS ($_remainingSeconds s)'
                                        : 'EMERGENCY 1-TAP SOS'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isHolding
                                    ? 'Release to cancel • Keep holding to dispatch'
                                    : (_isArmed
                                        ? 'Tap again now to transmit live GPS distress'
                                        : 'Hold 2s or 1-Tap • Direct EOC & NGO Dispatch'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.92),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Visual indicator pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isHolding
                                ? '${(holdProgress * 100).toInt()}%'
                                : (_isArmed ? 'CONFIRM' : 'ACTIVATE'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 3. CIRCULAR HERO BUTTON (FOR SOS SCREEN)
  Widget _buildCircularButton() {
    final size = widget.width ?? 180.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rippleAnimation, _holdController]),
      builder: (context, _) {
        final scale = (_isArmed || _isHolding) ? _pulseAnimation.value : 1.0;
        final rippleRadius = size * (1.0 + _rippleAnimation.value * 0.45);
        final rippleOpacity = (1.0 - _rippleAnimation.value).clamp(0.0, 0.6);
        final holdProgress = _holdController.value;

        return Center(
          child: SizedBox(
            width: size * 1.5,
            height: size * 1.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radiating radar ripple waves
                Container(
                  width: rippleRadius,
                  height: rippleRadius,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryRed.withOpacity(rippleOpacity),
                      width: 2.5,
                    ),
                  ),
                ),
                Container(
                  width: size * (1.0 + (_rippleAnimation.value * 0.25)),
                  height: size * (1.0 + (_rippleAnimation.value * 0.25)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryRed.withOpacity(rippleOpacity * 0.2),
                  ),
                ),

                // Main circular button
                Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTapDown: (_) => _onHoldStart(),
                    onTapUp: (_) => _onHoldEnd(),
                    onTapCancel: () => _onHoldEnd(),
                    onTap: () {
                      if (holdProgress < 0.2) {
                        _onQuickTap();
                      }
                    },
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isArmed
                            ? const RadialGradient(
                                colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
                                center: Alignment(-0.2, -0.2),
                              )
                            : const RadialGradient(
                                colors: [AppColors.primaryRed, Color(0xFFBE123C)],
                                center: Alignment(-0.2, -0.2),
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isArmed ? Colors.red : AppColors.primaryRed).withOpacity(0.55),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(
                          color: _isArmed ? Colors.yellowAccent : Colors.white,
                          width: _isArmed ? 4 : 3,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Circular Hold Progress Indicator
                          if (_isHolding)
                            SizedBox(
                              width: size - 6,
                              height: size - 6,
                              child: CircularProgressIndicator(
                                value: holdProgress,
                                strokeWidth: 6,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                backgroundColor: Colors.transparent,
                              ),
                            ),

                          // Inner Content
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              widget.isSubmitting
                                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                  : Icon(
                                      _isArmed ? Icons.warning_amber : Icons.emergency,
                                      size: size * 0.28,
                                      color: Colors.white,
                                    ),
                              const SizedBox(height: 6),
                              Text(
                                _isHolding
                                    ? '${(2.0 - holdProgress * 2.0).toStringAsFixed(1)}s'
                                    : (_isArmed ? 'CONFIRM ($_remainingSeconds)' : 'SOS'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: _isArmed ? 16 : 24,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isHolding
                                    ? 'HOLD TO SEND'
                                    : (_isArmed ? 'TAP TO DISPATCH' : 'HOLD 2s / 1-TAP'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

