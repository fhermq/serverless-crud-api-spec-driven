module.exports = {
    root: true,
    env: {
        node: true,
        es2022: true,
        jest: true,
        commonjs: true
    },
    extends: [
        'eslint:recommended'
    ],
    parserOptions: {
        ecmaVersion: 2022,
        sourceType: 'script' // CommonJS modules
    },
    rules: {
    // Code style
        'indent': ['error', 4], // 4 spaces for consistency with existing code
        'quotes': ['error', 'single'],
        'semi': ['error', 'always'],
        'comma-dangle': ['error', 'never'],
        'no-trailing-spaces': 'error',
        'eol-last': 'error',

        // Best practices
        'no-console': 'off', // Allow console for Lambda logging
        'no-debugger': 'error',
        'no-unused-vars': ['error', {
            'argsIgnorePattern': '^_',
            'varsIgnorePattern': '^_'
        }],
        'no-var': 'error',
        'prefer-const': 'error',
        'prefer-arrow-callback': 'error',

        // Error prevention
        'no-undef': 'error',
        'no-unreachable': 'error',
        'no-duplicate-imports': 'error',
        'no-self-compare': 'error',

        // Lambda specific
        'prefer-destructuring': ['error', {
            'array': false,
            'object': true
        }],
        'object-shorthand': 'error',

        // Node.js specific
        'no-process-exit': 'error',
        'no-path-concat': 'error'
    },
    overrides: [
        {
            files: ['**/*.test.js', '**/*.spec.js'],
            env: {
                jest: true
            },
            rules: {
                'no-console': 'off'
            }
        }
    ]
};
