## Goal

Provide RFC 6265 cookie header parsing and safe, standards-conforming serialization in `CookieDate`, `CookieSyntax`, `SetCookieString`, and `RequestCookie`.

## User Experience

- Build response cookies with `SetCookieString`, assigning `name` and `value` and adding attributes. `tostring` emits literal HTTP syntax such as `sid=abc; Path=/; Domain=example.com; HttpOnly`, never URL-encoded attributes.
- Parse legacy expiry dates with `CookieDate`; valid dates expose UTC Unix seconds through `get_unix_time()` and serialize as an English RFC 1123 date in GMT. Invalid dates set `failed = true`; requesting their timestamp or serialization raises an error.
- Parse request cookies with `RequestCookie`. Values, percent sequences, plus signs, and optional surrounding quotes remain literal. `get(name)` returns the last same-name value for compatibility; `getAll(name)` exposes every occurrence. Serialization preserves parsed duplicates and order. `set` replaces all same-name pairs at their first position; `unset` removes all of them.

## Architecture Decisions

- Follow RFC 6265 sections 4.1/4.2 for emitted headers and 5.1.1/5.2 for legacy date and Set-Cookie parsing. Parsing and generation have different requirements: permissively parsed cookie pairs may fail strict output validation. Malformed request pairs are skipped, not partially matched.
- Keep shared byte-level grammar validation in `CookieSyntax`. Cookie names are HTTP tokens; values are `cookie-octet` sequences, optionally quoted. Attribute values permit printable ASCII and spaces but not semicolons, controls, DEL, or non-ASCII bytes. Domain values must be ASCII DNS names; callers supply IDNA A-labels themselves.
- Calculate Gregorian UTC timestamps and weekdays arithmetically, not through local-time `os.time` or locale-sensitive date formatting. Legacy date parsing accepts RFC token delimiters, one/two-digit time fields, month-name prefixes, and the prescribed two-digit year pivot. Impossible calendar dates, years before 1601, and leap seconds are rejected.
- `SetCookieString:add` normalizes recognized attributes and replaces duplicates case-insensitively, keeping the last valid value. Invalid expiry, Max-Age, and SameSite values are ignored during parsing. Invalid or absent Path is omitted, delegating RFC default-path calculation to the browser because the header object has no request URI.
- Retain unknown extension attributes, subject to safe token names and attribute-value grammar. SameSite recognizes Strict, Lax, and None as an extension to RFC 6265. Browser storage policies, public-suffix/origin checks, cookie prefixes, and modern extension interactions such as SameSite=None requiring Secure are outside this header codec; it is not a cookie jar.

## Invariants

- No cookie header serialization automatically percent-encodes or percent-decodes application data. Encode arbitrary data explicitly before assigning a cookie value, for example with Base64.
- Max-Age is a relative decimal duration, never an absolute timestamp. Nonpositive durations serialize as `Max-Age=0` for deletion, following RFC 6265 section 5.2.2. Large positive durations remain decimal strings without floating-point truncation. Browsers decide expiry and apply Max-Age precedence over Expires.
- Expires serializes as a canonical GMT HTTP date, not Unix seconds. Its weekday is computed from the date; an incorrect input weekday does not change the timestamp.
- Response serialization rejects invalid names, values, domains, unsafe attributes, duplicate attributes, and ignored cookies. Secure and HttpOnly serialize without values. Date and duration validation also applies when callers modify the public attribute list directly.

## Compatibility Changes

- `SetCookieString:get("Expires")` now returns a canonical date string instead of the previous unfinished timestamp representation. `get("Max-Age")` returns a decimal seconds string instead of an absolute timestamp. Attribute lookup is case-insensitive.
- `RequestCookie` no longer applies implicit URL encoding/decoding. Callers that intentionally use percent-encoded payloads must encode/decode them explicitly. `set` validates supplied names and values instead of hiding invalid bytes through escaping.
- Existing `web.framework.Sessions` Base64 cookies remain compatible: Base64 uses valid cookie octets and its response cookies were already emitted without encoding the pair value. No configuration or stored-session migration is required for these sessions.

## Verification

Run `./test aqua/web/http` and `./test aqua/web/framework/Sessions`; also run cookie-date tests under a non-UTC `TZ` to verify timezone independence. Tests cover every byte against the cookie grammar, legacy date formats, leap-year boundaries, large/invalid durations, duplicate handling, injection rejection, literal values, and request/response round trips.
