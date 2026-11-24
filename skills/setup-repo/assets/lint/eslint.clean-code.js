const MAX_DEPTH = 3;
const MAX_PARAMS = 3;
const MAX_FUNCTION_LINES = 40;
const MAX_FILE_LINES = 200;
const MAX_COMPLEXITY = 10;
const ALLOWED_NUMBERS = [0, 1, -1, 2];
const SKIP = { skipBlankLines: true, skipComments: true };

export const cleanCodeRules = {
  rules: {
    "max-depth": ["error", MAX_DEPTH],
    "max-params": ["error", MAX_PARAMS],
    "max-lines-per-function": ["error", { max: MAX_FUNCTION_LINES, ...SKIP }],
    "max-lines": ["warn", { max: MAX_FILE_LINES, ...SKIP }],
    complexity: ["warn", MAX_COMPLEXITY],
    "no-param-reassign": ["error", { props: true }],
    "no-magic-numbers": ["warn", { ignore: ALLOWED_NUMBERS, ignoreArrayIndexes: true }],
    "no-empty": ["error", { allowEmptyCatch: false }],
  },
};
