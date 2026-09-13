/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: [
    '<rootDir>/test/**/*.spec.ts',
    '<rootDir>/test/**/*.e2e-spec.ts',
    '<rootDir>/src/**/*.spec.ts',
  ],
  moduleFileExtensions: ['ts', 'js', 'json'],
  clearMocks: true,
};
