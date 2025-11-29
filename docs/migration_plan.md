# Migration Plan: Project Jules

This plan details the steps to replace the existing `suno-automation` code with the "Project Jules" implementation.

## 1. Cleanup and Setup
*   **Action:** Remove all existing source code and irrelevant configuration.
*   **Files to Remove:**
    *   `src/index.js`
    *   `src/capture-session.js`
    *   `src/test.js`
    *   `scripts/` (if any)
    *   `input/` (if any)
    *   `package.json` (will be recreated or heavily modified)
    *   `package-lock.json`

## 2. Project Initialization
*   **Tech Stack Selection:** Node.js (keeping the language consistent but changing the libraries) or Python. The spec suggests "Python/Node". Node.js is a good fit for JSON handling and async HTTP requests. Let's stick with Node.js to minimize environment changes for the user, but switch to lightweight libraries.
*   **New Dependencies:**
    *   `axios` or `node-fetch` (for HTTP requests)
    *   `dotenv` (for environment variables)
    *   `fs-extra` (for file operations)

## 3. Implementation Steps

### Step 3.1: Configuration & Auth
*   Create a `.env` template for the Bearer token (`SUNO_TOKEN`).
*   Create a configuration module to load the token and define API endpoints.

### Step 3.2: API Client (`src/client.js`)
*   Implement a class/module to handle HTTP requests to `studio-api.suno.ai`.
*   Include the `Authorization: Bearer <token>` header in all requests.
*   Implement error handling (401 Unauthorized, Rate Limits).

### Step 3.3: Library Walker (`src/library.js`)
*   Implement logic to iterate through `/api/feed/?page=N`.
*   Handle pagination (detecting when no more results are available).
*   Aggregating song UUIDs and metadata.

### Step 3.4: Downloader (`src/downloader.js`)
*   For each track, extract the `audio_url`.
*   Download the `.mp3` file to a local `downloads/` directory.
*   Naming convention: `{title}-{id}.mp3` (or similar).

### Step 3.5: Manifest Generator (`src/main.js`)
*   Orchestrate the flow.
*   Generate the `jules_export.json` file matching the spec schema.

## 4. Verification
*   **Test:** Create a mock server or use a provided token (if safe) to verify the flow.
*   **Output Check:** Verify `jules_export.json` structure and downloaded files.

## 5. Execution Plan
1.  **Delete** old files.
2.  **Initialize** new `package.json`.
3.  **Implement** the Jules script.
4.  **Verify** functionality.
