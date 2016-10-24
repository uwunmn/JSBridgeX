'use strict';

const path  = require('path');

var buildPath = path.resolve(__dirname, './build/');

module.exports = {
    //页面入口文件配置
    entry: {
        index : './src/index.js'
    },
    //入口文件输出配置
    output: {
        path: buildPath,
        filename: '[name].js'
    },
    module: {
        loaders: [{
            test: /\.js$/,
            loader: 'babel'
        }]
    }
};