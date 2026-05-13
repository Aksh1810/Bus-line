String iconFromBearing(double b) {
  if (b >= 45 && b < 135) return 'assets/icons/stop_right.svg';
  if (b >= 135 && b < 225) return 'assets/icons/stop_down.svg';
  if (b >= 225 && b < 315) return 'assets/icons/stop_left.svg';
  return 'assets/icons/stop_up.svg';
}
