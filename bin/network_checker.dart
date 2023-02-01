import 'package:network_checker/network_checker.dart';

void main(List<String> arguments) {
  final networkChecker = NetworkChecker();

  networkChecker.start();

  networkChecker.onNetworkStatusChanged.listen((event) {
    print(event);
  });
}
