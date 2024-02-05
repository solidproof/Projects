const globalRngSettings = {
  error: {
    providerDontExist: 'GlobalRng: Unsupported provider',
    providerIsDisable: 'GlobalRng: Inactive provider',
    multipleChainlinkProvider: 'GlobalRng: Cannot set multiple chainlink provider',
    unauthorizedVrfCoordinator: 'GlobalRng: Only VRF coordinator can fullFill',
  },
};

const chainlinkProviderSettings = {
  setup: {
    name: 'chainlink',
    isActive: true,
    gasPriceLink: 100000,
    functionData:
      '0x5d3b1d30d89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000005f5e1000000000000000000000000000000000000000000000000000000000000000001',
    baseFee: 100000,
    keyHash: '0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc',
    numWords: 1,
    callbackGasLimit: 100000,
    requestConfirmations: 3,
    paramData: [0, 0, 0, 0, 0, 0],
  },
};

const customProviderSettings = {
  setup: {
    name: 'custom',
    isActive: true,
    gasPriceLink: 100000,
    functionData: '0x43ae9d970000000000000000000000000000000000000000000000000000000000000006',
    baseFee: 100000,
    providerAddress: '0x0000000000000000000000000000000000000001',
    keyHash: '0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc',
    callbackGasLimit: 100000,
    paramData: [0, 32, 10, 36, 36, 68],
  },
  secondSetup: {
    name: 'custom 2',
    isActive: false,
    gasPriceLink: 200000,
    functionData: '0x40ae9d970000000000000000000000000000000000000000000000000000000000000006',
    baseFee: 200000,
    keyHash: '0x909b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc',
    callbackGasLimit: 200000,
    paramData: [1, 33, 11, 37, 38, 69],
    providerAddress: '0x0000000000000000000000000000000000000002',
  },
};

module.exports = {
  globalRngSettings,
  chainlinkProviderSettings,
  customProviderSettings,
};
