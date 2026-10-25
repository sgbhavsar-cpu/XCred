interface ApiErrorShape {
  response?: { data?: { error?: { message?: string; code?: string } } };
}

const body = (err: unknown) => (err as ApiErrorShape | null)?.response?.data?.error;

/** The server's `{ error: { message } }` text from a failed axios call, else `fallback`. */
export function apiErrorMessage(err: unknown, fallback: string): string {
  return body(err)?.message ?? fallback;
}

/** The server's machine-readable `{ error: { code } }`, e.g. 'TARGET_NOT_EMPTY'. */
export function apiErrorCode(err: unknown): string | undefined {
  return body(err)?.code;
}
