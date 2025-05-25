import 'package:flutter/material.dart';

class OnlineStatusIndicator extends StatefulWidget {
  final bool isOnline;
  final double size;
  final Color onlineColor;
  final Color offlineColor;
  final bool pulsate;
  
  const OnlineStatusIndicator({
    Key? key,
    required this.isOnline,
    this.size = 12.0,
    this.onlineColor = Colors.green,
    this.offlineColor = Colors.grey,
    this.pulsate = true,
  }) : super(key: key);
  
  @override
  _OnlineStatusIndicatorState createState() => _OnlineStatusIndicatorState();
}

class _OnlineStatusIndicatorState extends State<OnlineStatusIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    if (widget.isOnline && widget.pulsate) {
      _animationController.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(OnlineStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 状态变更时重新处理动画
    if (widget.isOnline != oldWidget.isOnline) {
      if (widget.isOnline && widget.pulsate) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.isOnline ? widget.onlineColor : widget.offlineColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: widget.isOnline
            ? [
                BoxShadow(
                  color: widget.onlineColor.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: widget.isOnline && widget.pulsate
          ? AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.onlineColor,
                    boxShadow: [
                      BoxShadow(
                        color: widget.onlineColor.withOpacity(0.7 * _animation.value),
                        blurRadius: 8 * _animation.value,
                        spreadRadius: 2 * _animation.value,
                      ),
                    ],
                  ),
                );
              },
            )
          : null,
    );
  }
} 