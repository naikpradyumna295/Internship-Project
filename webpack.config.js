const MiniCssExtractPlugin = require("mini-css-extract-plugin");

module.exports = {
	entry: "./src/index.tsx",
	output: {
		path: `${__dirname}/dist`,
		filename: "bundle.js",
	},
	module: {
		rules: [
			{ test: /\.tsx?$/, use: "ts-loader" },
			{
				test: /\.(scss|sass|css)$/,
				use: [
					{ loader: MiniCssExtractPlugin.loader },
					{
						loader: "css-loader",
						options: {
							url: false,
							sourceMap: true,
							importLoaders: 2,
						},
					},
					{
						loader: "sass-loader",
						options: {
							sourceMap: true,
						},
					},
				],
			},
		]
	},
	resolve: {
		extensions: ["", ".ts", ".tsx", ".js", ".json"]
	},
	plugins: [
		new MiniCssExtractPlugin({ filename: "style.css" }),
	],
	target: ["web", "es2015"],
}