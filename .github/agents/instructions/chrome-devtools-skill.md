# Chrome DevTools Browser Verification Skill

This skill enables runtime browser verification using the `chrome-devtools` MCP server.
It is used by the Journey Verifier to supplement static reachability analysis with live
browser checks — navigating pages, inspecting console output, verifying DOM structure,
and capturing screenshots.

## When to Use

Use this skill when:

- **Runtime route verification** — Navigate to routes identified during static analysis
  and confirm they actually render without errors.
- **Console error detection** — Check for JavaScript errors, failed module imports, or
  runtime exceptions that static analysis cannot catch.
- **DOM structure verification** — Take accessibility snapshots to verify that expected
  elements (navigation links, buttons, forms, headings) are present on rendered pages.
- **Visual evidence** — Capture screenshots as artifacts for the verification report.
- **Network request inspection** — Identify failed API calls (4xx/5xx) or missing resources
  that would break functionality at runtime.

## Prerequisites

- The `chrome-devtools` MCP server must be configured in VS Code.
- A locally running dev server (the application must be accessible at a URL).
- If the MCP server is unavailable, the Journey Verifier falls back to static-only
  verification — this skill degrades gracefully.

## Tool Categories

### 1. Navigation & Page Management

- `navigate_page` — Go to a specific URL, reload, or navigate history.
- `new_page` — Open a new tab/page.
- `select_page` — Switch context between open pages.
- `list_pages` — See all open pages and their IDs.
- `close_page` — Close a specific page.
- `wait_for` — Wait for specific text to appear on the page.

### 2. Input & Interaction

- `click` — Click on an element (use `uid` from snapshot).
- `fill` / `fill_form` — Type text into inputs or fill multiple fields at once.
- `hover` — Move the mouse over an element.
- `press_key` — Send keyboard shortcuts or special keys (e.g., "Enter", "Control+C").
- `drag` — Drag and drop elements.
- `handle_dialog` — Accept or dismiss browser alerts/prompts.
- `upload_file` — Upload a file through a file input.

### 3. Debugging & Inspection

- `take_snapshot` — Get a text-based accessibility tree (best for identifying elements
  and verifying DOM structure). **Prefer this over screenshots for programmatic checks.**
- `take_screenshot` — Capture a visual representation of the page or a specific element.
- `list_console_messages` / `get_console_message` — Inspect the page's console output.
- `evaluate_script` — Run custom JavaScript in the page context.
- `list_network_requests` / `get_network_request` — Analyze network traffic and
  request details.

### 4. Emulation & Performance

- `resize_page` — Change the viewport dimensions.
- `emulate` — Throttle CPU/Network or emulate geolocation.
- `performance_start_trace` — Start recording a performance profile.
- `performance_stop_trace` — Stop recording and save the trace.
- `performance_analyze_insight` — Get detailed analysis from recorded performance data.

## Verification Workflow Patterns

### Pattern A: Route Verification (Primary)

For each route identified during static analysis:

1. `navigate_page` to the route URL.
2. `wait_for` a key element (page title, heading, or main content area) with a reasonable
   timeout (5–10 seconds).
3. `take_snapshot` to get the DOM structure — verify expected elements are present.
4. `list_console_messages` to check for JavaScript errors (filter for `error` type).
5. `take_screenshot` to capture visual evidence (saved as verification artifact).

### Pattern B: Navigation Flow Verification

Verify that navigation paths described in user stories actually work:

1. `navigate_page` to the application root / main entry point.
2. `take_snapshot` to find navigation elements (menus, links, buttons).
3. `click` on the navigation element (using `uid` from snapshot) to follow the path.
4. `wait_for` the target page to load.
5. `take_snapshot` to verify the destination page rendered correctly.

### Pattern C: Error Investigation

When a page fails to load or has errors:

1. `list_console_messages` to identify JavaScript errors.
2. `list_network_requests` to find failed (4xx/5xx) resources or API calls.
3. `evaluate_script` to check specific DOM state or global variables.
4. `take_screenshot` to capture the error state as evidence.

## Best Practices

- **Snapshot-first**: Always prefer `take_snapshot` over `take_screenshot` for identifying
  elements. Snapshots provide `uid` values required by interaction tools and are
  machine-readable.
- **Context awareness**: Run `list_pages` and `select_page` if unsure which tab is active.
- **Fresh snapshots**: Take a new snapshot after any major navigation or DOM change, as `uid`
  values may change.
- **Reasonable timeouts**: Use 5–10 second timeouts for `wait_for` to avoid hanging on
  slow-loading elements, but don't set them too short for dev servers.
- **Console filtering**: When checking `list_console_messages`, focus on `error` type messages.
  Warnings and info messages are noise for verification purposes.
- **Screenshots sparingly**: Use `take_screenshot` for visual evidence in the report, but rely
  on `take_snapshot` for programmatic verification logic.
- **Clean up**: Close pages with `close_page` when done to avoid resource leaks.

## Failure Classification

When browser verification finds issues, classify them for the Journey Verification Report:

| Severity | Description | Example |
|----------|-------------|---------|
| **🔴 Runtime Failure** | Page fails to render or has blocking JS errors | `TypeError: Cannot read property 'map' of undefined` |
| **🟡 Runtime Warning** | Page renders but has non-blocking console errors or failed non-critical network requests | 404 on a favicon, deprecation warning |
| **🟢 Runtime Pass** | Page loads, no console errors, expected elements present | Route renders correctly with all expected content |
