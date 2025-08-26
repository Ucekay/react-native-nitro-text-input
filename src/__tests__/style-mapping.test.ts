/**
 * @jest-environment jsdom
 */

import { mapStyleToTextAttributes } from '../style-mapping';

// Mock processColor since it's a React Native function
jest.mock('react-native', () => ({
  processColor: jest.fn((color: any) => {
    if (color === 'red') return 0xFFFF0000;
    if (color === 'blue') return 0xFF0000FF;
    if (color === '#00FF00') return 0xFF00FF00;
    return color;
  }),
}));

describe('mapStyleToTextAttributes', () => {
  it('should return undefined for undefined style', () => {
    expect(mapStyleToTextAttributes(undefined)).toBeUndefined();
  });

  it('should return undefined for empty style', () => {
    expect(mapStyleToTextAttributes({})).toBeUndefined();
  });

  it('should map color correctly', () => {
    const result = mapStyleToTextAttributes({ color: 'red' });
    expect(result).toEqual({
      color: 0xFFFF0000,
    });
  });

  it('should map fontSize correctly', () => {
    const result = mapStyleToTextAttributes({ fontSize: 16 });
    expect(result).toEqual({
      fontSize: 16,
    });
  });

  it('should map fontStyle correctly', () => {
    const result = mapStyleToTextAttributes({ fontStyle: 'italic' });
    expect(result).toEqual({
      fontStyle: 'italic',
    });
  });

  it('should map fontWeight correctly', () => {
    const result = mapStyleToTextAttributes({ fontWeight: 'bold' });
    expect(result).toEqual({
      fontWeight: 'bold',
    });
  });

  it('should map letterSpacing correctly', () => {
    const result = mapStyleToTextAttributes({ letterSpacing: 2 });
    expect(result).toEqual({
      letterSpacing: 2,
    });
  });

  it('should map lineHeight correctly', () => {
    const result = mapStyleToTextAttributes({ lineHeight: 20 });
    expect(result).toEqual({
      lineHeight: 20,
    });
  });

  it('should map textAlign correctly', () => {
    const result = mapStyleToTextAttributes({ textAlign: 'center' });
    expect(result).toEqual({
      textAlign: 'center',
    });
  });

  it('should map textDecorationColor correctly', () => {
    const result = mapStyleToTextAttributes({ textDecorationColor: 'blue' });
    expect(result).toEqual({
      textDecorationColor: 0xFF0000FF,
    });
  });

  it('should map textDecorationLine correctly', () => {
    const result = mapStyleToTextAttributes({ textDecorationLine: 'underline' });
    expect(result).toEqual({
      textDecorationLine: 'underline',
    });
  });

  it('should map textDecorationStyle correctly', () => {
    const result = mapStyleToTextAttributes({ textDecorationStyle: 'dashed' });
    expect(result).toEqual({
      textDecorationStyle: 'dashed',
    });
  });

  it('should map multiple style properties correctly', () => {
    const result = mapStyleToTextAttributes({
      color: '#00FF00',
      fontSize: 18,
      fontWeight: 'bold',
      textAlign: 'center',
      letterSpacing: 1,
    });
    
    expect(result).toEqual({
      color: 0xFF00FF00,
      fontSize: 18,
      fontWeight: 'bold',
      textAlign: 'center',
      letterSpacing: 1,
    });
  });

  it('should ignore non-text style properties', () => {
    const result = mapStyleToTextAttributes({
      color: 'red',
      fontSize: 16,
      // Non-text properties that should be ignored
      width: 100,
      height: 50,
      backgroundColor: 'white',
      borderWidth: 1,
    } as any);
    
    expect(result).toEqual({
      color: 0xFFFF0000,
      fontSize: 16,
    });
  });
});