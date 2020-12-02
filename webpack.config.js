const path = require("path");
const HTMLWebpackPlugin = require("html-webpack-plugin");
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const Dotenv = require('dotenv-webpack');

var config = {
    entry: {
        app: [
            './src/index.js',
        ],
    },

    output: {
        path: path.resolve(__dirname + '/dist'),
        filename: '[name].js',
    },

    module: {
        rules: [
            {
                test: /\.html$/,
                exclude: /node_modules/,
                loader: 'html-loader',
            },
            {
                test: /\.elm$/,
                exclude: [/elm-stuff/, /node_modules/],
                loader: 'elm-webpack-loader',
                options: {
                    verbose: true,
                    debug: true,
                }
            },
        ],

        noParse: /\.elm$/,
    },

    plugins: [
        new CleanWebpackPlugin(),
        new HTMLWebpackPlugin({
            // Use this template to get basic responsive meta tags
            template: "src/index.html",
            // inject details of output file at end of body
            inject: "body"
        }),
        new Dotenv({
            path: path.resolve(__dirname, './.env')
        })
    ],

    devServer: {
        port: process.env.PORT,
        contentBase: path.join(__dirname, 'src/assets'),
        inline: true,
        hot: true,
    },

    resolve: {
        modules: [ path.join(__dirname, "src"), "node_modules" ]
    }
};


module.exports = (env, argv) => {
    if (argv.mode === 'production') {
        config.module.rules[1].options['optimize'] = true;
        config.module.rules[1].options['debug'] = false;
    }
    return config;
};
