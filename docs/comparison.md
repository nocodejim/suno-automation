# Comparison: Existing Code vs. Project Jules Specification

This document compares the existing repository (`suno-automation`) with the new specification for "Project Jules".

## 1. Executive Summary

**Verdict:** The existing code is **completely unsuitable** for Project Jules and should be replaced entirely.

*   **Existing Code:** A "headless browser" automation tool for *generating* songs. It uses Playwright to control a Chrome instance, fill out forms, and click buttons. This corresponds to the "Service Wrapper Model" or "Headless Browser Fleet" architecture described in the spec's comparison section (2.1), although it's designed for a single user rather than a fleet.
*   **Project Jules Spec:** A "data liberation" tool for *exporting* existing library data. It explicitly rejects the headless browser approach in favor of a "Session Replay Model" using direct HTTP requests with a user-provided Bearer token.

## 2. Detailed Comparison

| Feature | Existing Code (`suno-automation`) | Project Jules Spec | Status |
| :--- | :--- | :--- | :--- |
| **Primary Goal** | **Song Generation:** Automates the creation of new songs from a CSV file. | **Data Export:** Retrieves metadata and audio for existing songs in the user's library. | ❌ Mismatch |
| **Architecture** | **Headless Browser (Playwright):** Launches a real browser, navigates to `suno.com/create`, interacts with DOM elements. | **HTTP Client (Session Replay):** Makes direct `GET` requests to `studio-api.suno.ai` using a Bearer token. | ❌ Mismatch |
| **Authentication** | **Cookies (`session.json`):** Requires capturing cookies via a browser script and replaying them in Playwright. | **Bearer Token (JWT):** User provides the `Authorization: Bearer <token>` string directly (BYOT). | ❌ Mismatch |
| **Target Endpoints** | `https://suno.com/create` (Web UI) and `api/generate/v2-web/` (via page evaluation). | `/api/feed/?page=1`, `/api/feed/<song_id>`, `/api/billing/info/`. | ❌ Mismatch |
| **Output** | `results.csv`: Tracks generation status and IDs. | `jules_export.json`: A structured manifest of the user's library with metadata and signed URLs. | ❌ Mismatch |
| **Tech Stack** | Node.js, Playwright, CSV Parser. | Python or Node.js (HTTP Client). | ⚠️ Partial Match (Node.js is acceptable) |

## 3. Analysis of Existing Code Quality

The existing code is a functional Playwright automation script for a specific task (bulk generation). It is well-structured for *that* purpose, with logging, retry logic, and configuration.

**However, for Project Jules, it is "junk" because:**
1.  **Wrong Tool for the Job:** Using a headless browser to scrape a JSON API is inefficient and brittle compared to direct HTTP requests.
2.  **Wrong Objective:** It creates data instead of reading it.
3.  **Unnecessary Complexity:** Playwright adds a massive dependency overhead (browser binaries) that is not needed for a simple API client.

## 4. Recommendation

**Replace 100% of the existing code.**

We should start fresh with a new implementation that focuses solely on the Project Jules requirements:
1.  Accept a Bearer token as input.
2.  Iterate through the `api/feed` pages.
3.  Download audio files and save metadata to a JSON manifest.
