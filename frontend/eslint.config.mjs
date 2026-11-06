import nextConfig from 'eslint-config-next';

const config = [
  ...nextConfig,
  {
    ignores: ['.next/**', 'node_modules/**', 'e2e/**'],
  },
];

export default config;
