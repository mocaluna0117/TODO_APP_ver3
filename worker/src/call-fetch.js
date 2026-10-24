// Workers の fetch は、オブジェクトのメソッドとして呼ぶ（this が付く）と
// "Illegal invocation" になるので、ctx から取り出してから関数として呼ぶ。
export function callFetch(ctx, input, init) {
  const fetchImpl = ctx.fetch;
  return fetchImpl(input, init);
}
