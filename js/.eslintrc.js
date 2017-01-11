module.exports = {
    "extends": "standard",
    "installedESLint": true,
    "plugins": [
        "standard",
        "promise"
    ],
    "rules": {
        "indent": ["warn", 4],
        "semi": ["error", "always"],
        "quotes": ["error", "single"],
        "space-before-function-paren": ["error", "never"]
    }
};