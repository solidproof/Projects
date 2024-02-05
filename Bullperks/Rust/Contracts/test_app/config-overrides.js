const webpack = require('webpack');

module.exports = function override (config, env) {
  console.log('override')
  let loaders = config.resolve
  loaders.fallback = {
    "assert": require.resolve("assert"),
    "fs": false,
    "os": false,
    "process": false,
    "path": false,
    "stream": false,
    "crypto": false,
    // "net": false,
    // "http": require.resolve("stream-http"),
    // "https": false,
    // "zlib": require.resolve("browserify-zlib") ,
    // "path": require.resolve("path-browserify"),
    // "stream": require.resolve("stream-browserify"),
    // "util": require.resolve("util/"),
    // "crypto": require.resolve("crypto-browserify")
  }
  config.plugins = (config.plugins || []).concat([
    new webpack.ProvidePlugin({
      process: 'process/browser.js',
    }),
  ]);
  return config
}