module.exports = {
    root: true,
    env: {
        es6: true,
        node: true,
    },
    extends: [
        "eslint:recommended",
    ],
    rules: {
        "quotes": ["error", "single"],
        "max-len": ["off"],
        "object-curly-spacing": ["off"],
        "indent": ["off"],
        "comma-dangle": ["off"],
        "require-jsdoc": ["off"],
        "valid-jsdoc": ["off"],
        "camelcase": ["off"],
        "no-undef": ["off"],
        "no-unused-vars": ["warn"]
    },
    parserOptions: {
        ecmaVersion: 2020, // Allows modern ECMAScript features
    },
};
