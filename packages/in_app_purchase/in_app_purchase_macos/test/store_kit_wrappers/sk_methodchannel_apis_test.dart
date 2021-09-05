// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_macos/src/channel.dart';
import 'package:in_app_purchase_macos/store_kit_wrappers.dart';
import 'sk_test_stub_objects.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final FakeMACOSPlatform fakeMACOSPlatform = FakeMACOSPlatform();

  setUpAll(() {
    SystemChannels.platform
        .setMockMethodCallHandler(fakeMACOSPlatform.onMethodCall);
  });

  setUp(() {});

  tearDown(() {
    fakeMACOSPlatform.testReturnNull = false;
    fakeMACOSPlatform.queueIsActive = null;
    fakeMACOSPlatform.getReceiptFailTest = false;
  });

  group('sk_request_maker', () {
    test('get products method channel', () async {
      SkProductResponseWrapper productResponseWrapper =
          await SKRequestMaker().startProductRequest(['xxx']);
      expect(
        productResponseWrapper.products,
        isNotEmpty,
      );
      expect(
        productResponseWrapper.products.first.priceLocale.currencySymbol,
        '\$',
      );

      expect(
        productResponseWrapper.products.first.priceLocale.currencySymbol,
        isNot('A'),
      );
      expect(
        productResponseWrapper.products.first.priceLocale.currencyCode,
        'USD',
      );
      expect(
        productResponseWrapper.products.first.priceLocale.countryCode,
        'US',
      );
      expect(
        productResponseWrapper.invalidProductIdentifiers,
        isNotEmpty,
      );

      expect(
        fakeMACOSPlatform.startProductRequestParam,
        ['xxx'],
      );
    });

    test('get products method channel should throw exception', () async {
      fakeMACOSPlatform.getProductRequestFailTest = true;
      expect(
        SKRequestMaker().startProductRequest(<String>['xxx']),
        throwsException,
      );
      fakeMACOSPlatform.getProductRequestFailTest = false;
    });

    test('refreshed receipt', () async {
      int receiptCountBefore = fakeMACOSPlatform.refreshReceipt;
      await SKRequestMaker().startRefreshReceiptRequest(
          receiptProperties: <String, dynamic>{"isExpired": true});
      expect(fakeMACOSPlatform.refreshReceipt, receiptCountBefore + 1);
      expect(fakeMACOSPlatform.refreshReceiptParam,
          <String, dynamic>{"isExpired": true});
    });

    test('should get null receipt if any exceptions are raised', () async {
      fakeMACOSPlatform.getReceiptFailTest = true;
      expect(() async => SKReceiptManager.retrieveReceiptData(),
          throwsA(TypeMatcher<PlatformException>()));
    });
  });

  group('sk_receipt_manager', () {
    test('should get receipt (faking it by returning a `receipt data` string)',
        () async {
      String receiptData = await SKReceiptManager.retrieveReceiptData();
      expect(receiptData, 'receipt data');
    });
  });

  group('sk_payment_queue', () {
    test('canMakePayment should return true', () async {
      expect(await SKPaymentQueueWrapper.canMakePayments(), true);
    });

    test('canMakePayment returns false if method channel returns null',
        () async {
      fakeMACOSPlatform.testReturnNull = true;
      expect(await SKPaymentQueueWrapper.canMakePayments(), false);
    });

    test('transactions should return a valid list of transactions', () async {
      expect(await SKPaymentQueueWrapper().transactions(), isNotEmpty);
    });

    test(
        'throws if observer is not set for payment queue before adding payment',
        () async {
      expect(SKPaymentQueueWrapper().addPayment(dummyPayment),
          throwsAssertionError);
    });

    test('should add payment to the payment queue', () async {
      SKPaymentQueueWrapper queue = SKPaymentQueueWrapper();
      TestPaymentTransactionObserver observer =
          TestPaymentTransactionObserver();
      queue.setTransactionObserver(observer);
      await queue.addPayment(dummyPayment);
      expect(fakeMACOSPlatform.payments.first, equals(dummyPayment));
    });

    test('should finish transaction', () async {
      SKPaymentQueueWrapper queue = SKPaymentQueueWrapper();
      TestPaymentTransactionObserver observer =
          TestPaymentTransactionObserver();
      queue.setTransactionObserver(observer);
      await queue.finishTransaction(dummyTransaction);
      expect(fakeMACOSPlatform.transactionsFinished.first,
          equals(dummyTransaction.toFinishMap()));
    });

    test('should restore transaction', () async {
      SKPaymentQueueWrapper queue = SKPaymentQueueWrapper();
      TestPaymentTransactionObserver observer =
          TestPaymentTransactionObserver();
      queue.setTransactionObserver(observer);
      await queue.restoreTransactions(applicationUserName: 'aUserID');
      expect(
          fakeMACOSPlatform.applicationNameHasTransactionRestored, 'aUserID');
    });

    test('startObservingTransactionQueue should call methodChannel', () async {
      expect(fakeMACOSPlatform.queueIsActive, isNot(true));
      await SKPaymentQueueWrapper().startObservingTransactionQueue();
      expect(fakeMACOSPlatform.queueIsActive, true);
    });

    test('stopObservingTransactionQueue should call methodChannel', () async {
      expect(fakeMACOSPlatform.queueIsActive, isNot(false));
      await SKPaymentQueueWrapper().stopObservingTransactionQueue();
      expect(fakeMACOSPlatform.queueIsActive, false);
    });

    test('setDelegate should call methodChannel', () async {
      expect(fakeMACOSPlatform.isPaymentQueueDelegateRegistered, false);
      await SKPaymentQueueWrapper().setDelegate(TestPaymentQueueDelegate());
      expect(fakeMACOSPlatform.isPaymentQueueDelegateRegistered, true);
      await SKPaymentQueueWrapper().setDelegate(null);
      expect(fakeMACOSPlatform.isPaymentQueueDelegateRegistered, false);
    });

    test('showPriceConsentIfNeeded should call methodChannel', () async {
      expect(fakeMACOSPlatform.showPriceConsentIfNeeded, false);
      await SKPaymentQueueWrapper().showPriceConsentIfNeeded();
      expect(fakeMACOSPlatform.showPriceConsentIfNeeded, true);
    });
  });

  group('Code Redemption Sheet', () {
    test('presentCodeRedemptionSheet should not throw', () async {
      expect(fakeMACOSPlatform.presentCodeRedemption, false);
      await SKPaymentQueueWrapper().presentCodeRedemptionSheet();
      expect(fakeMACOSPlatform.presentCodeRedemption, true);
      fakeMACOSPlatform.presentCodeRedemption = false;
    });
  });
}

class FakeMACOSPlatform {
  FakeMACOSPlatform() {
    channel.setMockMethodCallHandler(onMethodCall);
  }
  // get product request
  List<dynamic> startProductRequestParam = [];
  bool getProductRequestFailTest = false;
  bool testReturnNull = false;

  // get receipt request
  bool getReceiptFailTest = false;

  // refresh receipt request
  int refreshReceipt = 0;
  late Map<String, dynamic> refreshReceiptParam;

  // payment queue
  List<SKPaymentWrapper> payments = [];
  List<Map<String, String>> transactionsFinished = [];
  String applicationNameHasTransactionRestored = '';

  // present Code Redemption
  bool presentCodeRedemption = false;

  // show price consent sheet
  bool showPriceConsentIfNeeded = false;

  // indicate if the payment queue delegate is registered
  bool isPaymentQueueDelegateRegistered = false;

  // Listen to purchase updates
  bool? queueIsActive;

  Future<dynamic> onMethodCall(MethodCall call) {
    switch (call.method) {
      // request makers
      case '-[InAppPurchasePlugin startProductRequest:result:]':
        startProductRequestParam = call.arguments;
        if (getProductRequestFailTest) {
          return Future<dynamic>.value(null);
        }
        return Future<Map<String, dynamic>>.value(
            buildProductResponseMap(dummyProductResponseWrapper));
      case '-[InAppPurchasePlugin refreshReceipt:result:]':
        refreshReceipt++;
        refreshReceiptParam =
            Map.castFrom<dynamic, dynamic, String, dynamic>(call.arguments);
        return Future<void>.sync(() {});
      // receipt manager
      case '-[InAppPurchasePlugin retrieveReceiptData:result:]':
        if (getReceiptFailTest) {
          throw ("some arbitrary error");
        }
        return Future<String>.value('receipt data');
      // payment queue
      case '-[SKPaymentQueue canMakePayments:]':
        if (testReturnNull) {
          return Future<dynamic>.value(null);
        }
        return Future<bool>.value(true);
      case '-[SKPaymentQueue transactions]':
        return Future<List<dynamic>>.value(
            [buildTransactionMap(dummyTransaction)]);
      case '-[InAppPurchasePlugin addPayment:result:]':
        payments.add(SKPaymentWrapper.fromJson(
            Map<String, dynamic>.from(call.arguments)));
        return Future<void>.sync(() {});
      case '-[InAppPurchasePlugin finishTransaction:result:]':
        transactionsFinished.add(Map<String, String>.from(call.arguments));
        return Future<void>.sync(() {});
      case '-[InAppPurchasePlugin restoreTransactions:result:]':
        applicationNameHasTransactionRestored = call.arguments;
        return Future<void>.sync(() {});
      case '-[InAppPurchasePlugin presentCodeRedemptionSheet:result:]':
        presentCodeRedemption = true;
        return Future<void>.sync(() {});
      case '-[SKPaymentQueue startObservingTransactionQueue]':
        queueIsActive = true;
        return Future<void>.sync(() {});
      case '-[SKPaymentQueue stopObservingTransactionQueue]':
        queueIsActive = false;
        return Future<void>.sync(() {});
      case '-[SKPaymentQueue registerDelegate]':
        isPaymentQueueDelegateRegistered = true;
        return Future<void>.sync(() {});
      case '-[SKPaymentQueue removeDelegate]':
        isPaymentQueueDelegateRegistered = false;
        return Future<void>.sync(() {});
      case '-[SKPaymentQueue showPriceConsentIfNeeded]':
        showPriceConsentIfNeeded = true;
        return Future<void>.sync(() {});
    }
    return Future.error('method not mocked');
  }
}

class TestPaymentQueueDelegate extends SKPaymentQueueDelegateWrapper {}

class TestPaymentTransactionObserver extends SKTransactionObserverWrapper {
  void updatedTransactions(
      {required List<SKPaymentTransactionWrapper> transactions}) {}

  void removedTransactions(
      {required List<SKPaymentTransactionWrapper> transactions}) {}

  void restoreCompletedTransactionsFailed({required SKError error}) {}

  void paymentQueueRestoreCompletedTransactionsFinished() {}

  bool shouldAddStorePayment(
      {required SKPaymentWrapper payment, required SKProductWrapper product}) {
    return true;
  }
}
