// Merge into an existing flat ESLint config (eslint.config.js). Enforces the mechanical half of
// the clean-code rule: nesting, params, function and file size, parameter mutation.
export const cleanCodeRules = {
  rules: {
    "max-depth": ["error", 3],
    "max-params": ["error", 3],
    "max-lines-per-function": [
      "error",
      { max: 40, skipBlankLines: true, skipComments: true },
    ],
    "max-lines": ["warn", { max: 200, skipBlankLines: true, skipComments: true }],
    complexity: ["warn", 10],
    "no-param-reassign": ["error", { props: true }],
    "no-magic-numbers": ["warn", { ignore: [0, 1, -1, 2], ignoreArrayIndexes: true }],
    "no-empty": ["error", { allowEmptyCatch: false }],
  },
};

// Usage in eslint.config.js:
//   import { cleanCodeRules } from "./eslint.clean-code.js";
//   export default [ /* existing entries */, { files: ["src/**/*.{ts,tsx,js,jsx}"], ...cleanCodeRules } ];
// Relax per file with an override block for tests, generated code and data tables.
