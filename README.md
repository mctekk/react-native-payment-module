# react-native-mc-payment-module

## Getting started

`$ npm install react-native-payment-module --save`

### Inside your projects/ios

`$ pod install`

## Usage

```
  // MODIFY FILE: in your react native project modify metro.config.js file

const blacklist = require('metro-config/src/defaults/blacklist');

module.exports = {
  resolver: {
    blacklistRE: blacklist([
      /node_modules\/.*\/node_modules\/react-native\/.*/,
    ])
  },
  transformer: {
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: false,
        inlineRequires: false,
      },
    }),
  },
};
```


```javascript
import PaymentModule from 'react-native-mc-payment-module';

// TODO: What to do with the module?
McPaymentModule;
  const {buyProduct, getItems} = PaymentModule;

  // GET ALL PRODUCTS
  // ARRAY: your array of products: ['producrt1', 'producrt2']
  
 getItems(['product1', 'products2'])
  .then((data) => {
    console.log({ data })
  })
  .catch((error) => {
    console.log(error)
  })
  // ARRAY: your array of products: your producrtId
  // pase as a second param true or false if you need to cancel a preview purchase. recommended true
     buyProduct('productId', true)
    .then((data) => {
      console.log(data);
    })
    .catch((Error) => {
      console.log(Error)
    }) 
```
