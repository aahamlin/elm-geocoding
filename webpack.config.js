const path = require("path");
const { CleanWebpackPlugin } = require('clean-webpack-plugin');

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
                loader: 'file-loader',
                options: {
                    name: '[name].[ext]'
                }
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
    ],

    devServer: {
        contentBase: path.join(__dirname, 'dist'),
        inline: false,
    },

    resolve: {
        modules: [ "src", "src/assets", "node_modules" ]
    }
};


module.exports = (env, argv) => {
    if (argv.mode === 'production') {
        config.module.rules[1].options['optimize'] = true;
        config.module.rules[1].options['debug'] = false;
    }
    return config;
};
