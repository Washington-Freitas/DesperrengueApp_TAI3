import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet_models.dart';
import '../services/wallet_service.dart';

/// Camada reativa da carteira (Riverpod). Streams de Realtime: o saldo e o extrato
/// mudam na tela assim que o banco muda (recarga, retenção, liberação, estorno).
final walletServiceProvider = Provider<WalletService>((ref) => WalletService());

/// Saldo disponível + valor protegido em custódia.
final walletProvider = StreamProvider.autoDispose<ClientWallet>((ref) => ref.watch(walletServiceProvider).walletStream());

/// Extrato cronológico.
final statementProvider = StreamProvider.autoDispose<List<WalletEntry>>((ref) => ref.watch(walletServiceProvider).statementStream());
