//
//  react-native-payment-module.m
//
//  Created by mctekkdev on 12/11/19.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PaymentModule.h"

////////////////////////////////////////////////////     _//////////_  // Private Members
@interface PaymentModule() <SKRequestDelegate> {
    NSMutableDictionary *promisesByKey;
    dispatch_queue_t myQueue;
    BOOL hasListeners;
    BOOL pendingTransactionWithAutoFinish;
    void (^receiptBlock)(NSData*, NSError*); // Block to handle request the receipt async from delegate
}
@end

@implementation PaymentModule

-(instancetype)init {
    if ((self = [super init])) {
        promisesByKey = [NSMutableDictionary dictionary];
        pendingTransactionWithAutoFinish = false;
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
//        [IAPPromotionObserver sharedObserver].delegate = self;
    }
    myQueue = dispatch_queue_create("reject", DISPATCH_QUEUE_SERIAL);
    validProducts = [NSMutableArray array];
    return self;
}

+(BOOL)requiresMainQueueSetup {
    return YES;
}

// Add to valid products from Apple server response. Allowing getProducts, getSubscriptions call several times.
// Doesn't allow duplication. Replace new product.
-(void)addProduct:(SKProduct *)aProd {
    NSLog(@"\n  Add new object : %@", aProd.productIdentifier);
    int delTar = -1;
    for (int k = 0; k < validProducts.count; k++) {
        SKProduct *cur = validProducts[k];
        if ([cur.productIdentifier isEqualToString:aProd.productIdentifier]) {
            delTar = k;
        }
    }
    if (delTar >= 0) {
        [validProducts removeObjectAtIndex:delTar];
    }
    [validProducts addObject:aProd];
}

- (NSMutableArray *)getDiscountData:(NSArray *)discounts {
    NSMutableArray *mappedDiscounts = [NSMutableArray arrayWithCapacity:[discounts count]];
    NSString *localizedPrice;
    NSString *paymendMode;
    NSString *subscriptionPeriods;
    NSString *discountType;

    if (@available(iOS 11.2, *)) {
        for(SKProductDiscount *discount in discounts) {
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            formatter.numberStyle = NSNumberFormatterCurrencyStyle;
            formatter.locale = discount.priceLocale;
            localizedPrice = [formatter stringFromNumber:discount.price];
            NSString *numberOfPeriods;

            switch (discount.paymentMode) {
                case SKProductDiscountPaymentModeFreeTrial:
                    paymendMode = @"FREETRIAL";
                    numberOfPeriods = [@(discount.subscriptionPeriod.numberOfUnits) stringValue];
                    break;
                case SKProductDiscountPaymentModePayAsYouGo:
                    paymendMode = @"PAYASYOUGO";
                    numberOfPeriods = [@(discount.numberOfPeriods) stringValue];
                    break;
                case SKProductDiscountPaymentModePayUpFront:
                    paymendMode = @"PAYUPFRONT";
                    numberOfPeriods = [@(discount.subscriptionPeriod.numberOfUnits) stringValue];
                    break;
                default:
                    paymendMode = @"";
                    numberOfPeriods = @"0";
                    break;
            }

            switch (discount.subscriptionPeriod.unit) {
                case SKProductPeriodUnitDay:
                    subscriptionPeriods = @"DAY";
                    break;
                case SKProductPeriodUnitWeek:
                    subscriptionPeriods = @"WEEK";
                    break;
                case SKProductPeriodUnitMonth:
                    subscriptionPeriods = @"MONTH";
                    break;
                case SKProductPeriodUnitYear:
                    subscriptionPeriods = @"YEAR";
                    break;
                default:
                    subscriptionPeriods = @"";
            }


            NSString* discountIdentifier = @"";
            #if __IPHONE_12_2
            if (@available(iOS 12.2, *)) {
                discountIdentifier = discount.identifier;
                switch (discount.type) {
                    case SKProductDiscountTypeIntroductory:
                        discountType = @"INTRODUCTORY";
                        break;
                    case SKProductDiscountTypeSubscription:
                        discountType = @"SUBSCRIPTION";
                        break;
                    default:
                        discountType = @"";
                        break;
                }

            }
            #endif

            [mappedDiscounts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                        discountIdentifier, @"identifier",
                                        discountType, @"type",
                                        numberOfPeriods, @"numberOfPeriods",
                                        discount.price, @"price",
                                        localizedPrice, @"localizedPrice",
                                        paymendMode, @"paymentMode",
                                        subscriptionPeriods, @"subscriptionPeriod",
                                        nil
                                        ]];
        }
    }

    return mappedDiscounts;
}


-(NSDictionary*)getProductObject:(SKProduct *)product {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = product.priceLocale;

    NSString* localizedPrice = [formatter stringFromNumber:product.price];
    NSString* introductoryPrice = localizedPrice;

    NSString* introductoryPricePaymentMode = @"";
    NSString* introductoryPriceNumberOfPeriods = @"";
    NSString* introductoryPriceSubscriptionPeriod = @"";

    NSString* currencyCode = @"";
    NSString* periodNumberIOS = @"0";
    NSString* periodUnitIOS = @"";

    NSString* itemType = @"Do not use this. It returned sub only before";

    if (@available(iOS 11.2, *)) {
        // itemType = product.subscriptionPeriod ? @"sub" : @"iap";
        unsigned long numOfUnits = (unsigned long) product.subscriptionPeriod.numberOfUnits;
        SKProductPeriodUnit unit = product.subscriptionPeriod.unit;

        if (unit == SKProductPeriodUnitYear) {
            periodUnitIOS = @"YEAR";
        } else if (unit == SKProductPeriodUnitMonth) {
            periodUnitIOS = @"MONTH";
        } else if (unit == SKProductPeriodUnitWeek) {
            periodUnitIOS = @"WEEK";
        } else if (unit == SKProductPeriodUnitDay) {
            periodUnitIOS = @"DAY";
        }

        periodNumberIOS = [NSString stringWithFormat:@"%lu", numOfUnits];

        // subscriptionPeriod = product.subscriptionPeriod ? [product.subscriptionPeriod stringValue] : @"";
        //introductoryPrice = product.introductoryPrice != nil ? [NSString stringWithFormat:@"%@", product.introductoryPrice] : @"";
        if (product.introductoryPrice != nil) {

            //SKProductDiscount introductoryPriceObj = product.introductoryPrice;
            formatter.locale = product.introductoryPrice.priceLocale;
            introductoryPrice = [formatter stringFromNumber:product.introductoryPrice.price];

            switch (product.introductoryPrice.paymentMode) {
                case SKProductDiscountPaymentModeFreeTrial:
                    introductoryPricePaymentMode = @"FREETRIAL";
                    introductoryPriceNumberOfPeriods = [@(product.introductoryPrice.subscriptionPeriod.numberOfUnits) stringValue];
                    break;
                case SKProductDiscountPaymentModePayAsYouGo:
                    introductoryPricePaymentMode = @"PAYASYOUGO";
                    introductoryPriceNumberOfPeriods = [@(product.introductoryPrice.numberOfPeriods) stringValue];
                    break;
                case SKProductDiscountPaymentModePayUpFront:
                    introductoryPricePaymentMode = @"PAYUPFRONT";
                    introductoryPriceNumberOfPeriods = [@(product.introductoryPrice.subscriptionPeriod.numberOfUnits) stringValue];
                    break;
                default:
                    introductoryPricePaymentMode = @"";
                    introductoryPriceNumberOfPeriods = @"0";
                    break;
            }

            if (product.introductoryPrice.subscriptionPeriod.unit == SKProductPeriodUnitDay) {
                introductoryPriceSubscriptionPeriod = @"DAY";
            } else if (product.introductoryPrice.subscriptionPeriod.unit == SKProductPeriodUnitWeek) {
                introductoryPriceSubscriptionPeriod = @"WEEK";
            } else if (product.introductoryPrice.subscriptionPeriod.unit == SKProductPeriodUnitMonth) {
                introductoryPriceSubscriptionPeriod = @"MONTH";
            } else if (product.introductoryPrice.subscriptionPeriod.unit == SKProductPeriodUnitYear) {
                introductoryPriceSubscriptionPeriod = @"YEAR";
            } else {
                introductoryPriceSubscriptionPeriod = @"";
            }

        } else {
            introductoryPrice = @"";
            introductoryPricePaymentMode = @"";
            introductoryPriceNumberOfPeriods = @"";
            introductoryPriceSubscriptionPeriod = @"";
        }
    }

    if (@available(iOS 10.0, *)) {
        currencyCode = product.priceLocale.currencyCode;
    }

    NSArray *discounts;
    #if __IPHONE_12_2
    if (@available(iOS 12.2, *)) {
        discounts = [self getDiscountData:[product.discounts copy]];
    }
    #endif

    NSDictionary *obj = [NSDictionary dictionaryWithObjectsAndKeys:
                         product.productIdentifier, @"productId",
                         [product.price stringValue], @"price",
                         currencyCode, @"currency",
                         itemType, @"type",
                         product.localizedTitle ? product.localizedTitle : @"", @"title",
                         product.localizedDescription ? product.localizedDescription : @"", @"description",
                         localizedPrice, @"localizedPrice",
                         periodNumberIOS, @"subscriptionPeriodNumberIOS",
                         periodUnitIOS, @"subscriptionPeriodUnitIOS",
                         introductoryPrice, @"introductoryPrice",
                         introductoryPricePaymentMode, @"introductoryPricePaymentModeIOS",
                         introductoryPriceNumberOfPeriods, @"introductoryPriceNumberOfPeriodsIOS",
                         introductoryPriceSubscriptionPeriod, @"introductoryPriceSubscriptionPeriodIOS",
                         discounts, @"discounts",
                         nil
                         ];

    return obj;
}

-(void)purchaseProcess:(SKPaymentTransaction *)transaction {
    if (pendingTransactionWithAutoFinish) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        pendingTransactionWithAutoFinish = false;
    }
    [self getPurchaseData:transaction withBlock:^(NSDictionary *purchase) {
        [self resolvePromisesForKey:RCTKeyForInstance(transaction.payment.productIdentifier) value:purchase];

        // additionally send event
        if (self->hasListeners) {
            [self sendEventWithName:@"purchase-updated" body: purchase];
        }
    }];
}

- (void) getPurchaseData:(SKPaymentTransaction *)transaction withBlock:(void (^)(NSDictionary *transactionDict))block {
    [self requestReceiptDataWithBlock:^(NSData *receiptData, NSError *error) {
        if (receiptData == nil) {
            block(nil);
        }
        else {
            NSMutableDictionary *purchase = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             @(transaction.transactionDate.timeIntervalSince1970 * 1000), @"transactionDate",
                                             transaction.transactionIdentifier, @"transactionId",
                                             transaction.payment.productIdentifier, @"productId",
                                             [receiptData base64EncodedStringWithOptions:0], @"transactionReceipt",
                                             nil
                                             ];

            // originalTransaction is available for restore purchase and purchase of cancelled/expired subscriptions
            SKPaymentTransaction *originalTransaction = transaction.originalTransaction;
            if (originalTransaction) {
                purchase[@"originalTransactionDateIOS"] = @(originalTransaction.transactionDate.timeIntervalSince1970 * 1000);
                purchase[@"originalTransactionIdentifierIOS"] = originalTransaction.transactionIdentifier;
            }

            block(purchase);
        }
    }];
}

- (BOOL) isReceiptPresent {
    NSURL *receiptURL = [[NSBundle mainBundle]appStoreReceiptURL];
    NSError *canReachError = nil;
    [receiptURL checkResourceIsReachableAndReturnError:&canReachError];
    return canReachError == nil;
}


- (NSData *) receiptData {
    NSURL *receiptURL = [[NSBundle mainBundle]appStoreReceiptURL];
    NSData *receiptData = [[NSData alloc]initWithContentsOfURL:receiptURL];
    return receiptData;
}

#pragma mark - Receipt

- (void) requestReceiptDataWithBlock:(void (^)(NSData *data, NSError *error))block {
    if ([self isReceiptPresent] == NO) {
        SKReceiptRefreshRequest *refreshRequest = [[SKReceiptRefreshRequest alloc]init];
        refreshRequest.delegate = self;
        [refreshRequest start];
        receiptBlock = block;
    }
    else {
        receiptBlock = nil;
        block([self receiptData], nil);
    }
}

-(void)resolvePromisesForKey:(NSString*)key value:(id)value {
    NSMutableArray* promises = [promisesByKey valueForKey:key];

    if (promises != nil) {
        for (NSMutableArray *tuple in promises) {
            RCTPromiseResolveBlock resolveBlck = tuple[0];
            resolveBlck(value);
        }
        [promisesByKey removeObjectForKey:key];
    }
}


- (void)productsRequest:(nonnull SKProductsRequest *)request didReceiveResponse:(nonnull SKProductsResponse *)response {
  
      for (SKProduct* prod in response.products) {
      [self addProduct:prod];
  }
  
  NSMutableArray* items = [NSMutableArray array];

  for (SKProduct* product in validProducts) {
      [items addObject:[self getProductObject:product]];
  }

  [self resolvePromisesForKey:RCTKeyForInstance(request) value:items];
}

- (void)paymentQueue:(nonnull SKPaymentQueue *)queue updatedTransactions:(nonnull NSArray<SKPaymentTransaction *> *)transactions {
  
  for (SKPaymentTransaction *transaction in transactions) {
   switch (transaction.transactionState) {
       case SKPaymentTransactionStatePurchasing:
           NSLog(@"\n\n Purchase Started !! \n\n");
           break;
       case SKPaymentTransactionStatePurchased:
           NSLog(@"\n\n\n\n\n Purchase Successful !! \n\n\n\n\n.");
              [self purchaseProcess:transaction];
           break;
       case SKPaymentTransactionStateRestored:
           NSLog(@"Restored ");
           [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
           break;
       case SKPaymentTransactionStateDeferred:
           NSLog(@"Deferred (awaiting approval via parental controls, etc.)");
           break;
       
   }
  }
}

static NSString *RCTKeyForInstance(id instance)
{
    return [NSString stringWithFormat:@"%p", instance];
}

-(void)addPromiseForKey:(NSString*)key resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    NSMutableArray* promises = [promisesByKey valueForKey:key];

    if (promises == nil) {
        promises = [NSMutableArray array];
        [promisesByKey setValue:promises forKey:key];
    }

    [promises addObject:@[resolve, reject]];
}



////////////////////////////////////////////////////     _//////////_//      EXPORT_MODULE
RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"iap-promoted-product", @"purchase-updated", @"purchase-error"];
}

RCT_EXPORT_METHOD(canMakePayments:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    BOOL canMakePayments = [SKPaymentQueue canMakePayments];
    resolve(@(canMakePayments));
}


RCT_EXPORT_METHOD(getProducts:(NSArray*)skus
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    NSSet* productIdentifiers = [NSSet setWithArray:skus];
    productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    productsRequest.delegate = self;
    NSString* key = RCTKeyForInstance(productsRequest);
    [self addPromiseForKey:key resolve:resolve reject:reject];
    [productsRequest start];
}

RCT_EXPORT_METHOD(buyProduct:(NSString*)sku
                  andDangerouslyFinishTransactionAutomatically:(BOOL)finishAutomatically
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    pendingTransactionWithAutoFinish = finishAutomatically;
    SKProduct *product;
    for (SKProduct *p in validProducts) {
        if([sku isEqualToString:p.productIdentifier]) {
            product = p;
            break;
        }
    }
    if (product) {
        NSString *key = RCTKeyForInstance(product.productIdentifier);
        [self addPromiseForKey:key resolve:resolve reject:reject];
            
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    } else {
        if (hasListeners) {
            NSDictionary *err = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"Invalid product ID.", @"debugMessage",
                                 @"E_DEVELOPER_ERROR", @"code",
                                 @"Invalid product ID.", @"message",
                                 nil
                                 ];
            [self sendEventWithName:@"purchase-error" body:err];
        }
        reject(@"E_DEVELOPER_ERROR", @"Invalid product ID.", nil);
    }
}


@end