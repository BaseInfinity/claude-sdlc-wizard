import { describe, it, expect } from 'vitest';
import { greet, add } from '../src/index';

describe('greet', () => {
  it('returns greeting with name', () => {
    expect(greet('World')).toBe('Hello, World!');
  });
});

describe('add', () => {
  it('adds two numbers', () => {
    expect(add(1, 2)).toBe(3);
  });
});
