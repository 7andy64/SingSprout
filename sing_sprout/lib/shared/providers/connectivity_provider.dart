import 'package:flutter/foundation.dart';

/// 网络连接状态管理 stub（web 预览模式）
class ConnectivityProvider extends ChangeNotifier {
  bool _isConnected = true;

  ConnectivityProvider() {}

  bool get isConnected => _isConnected;

  void setOnline(bool online) {
    if (online != _isConnected) {
      _isConnected = online;
      notifyListeners();
    }
  }

  @override
  void dispose() => super.dispose();
}
