import { dirname } from 'path';
import { fileURLToPath } from 'url';
import { defineConfig, globals } from 'globals';
import plugin from 'eslint-config-next';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const eslintrc = defineConfig([
  { ignores: ['.next/**', 'node_modules/**', 'e2e/**'] },
  {
    extends: [plugin],
    files: ['**/*.{js,jsx,ts,tsx}'],
    globals: globals.es2020,
    languageOptions: {
      ecmaVersion: 2020,
    },
  },
]);

export default eslintrc;
