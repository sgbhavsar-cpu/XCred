declare module 'argon2-browser' {
  export enum ArgonType { Argon2d = 0, Argon2i = 1, Argon2id = 2 }
  export interface HashOptions {
    pass: string;
    salt: Uint8Array | string;
    time?: number;
    mem?: number;
    parallelism?: number;
    hashLen?: number;
    type?: ArgonType;
  }
  export interface HashResult {
    hash: Uint8Array;
    hashHex: string;
    encoded: string;
  }
  export function hash(options: HashOptions): Promise<HashResult>;
  export function verify(options: { pass: string; encoded: string; type?: ArgonType }): Promise<void>;
}
