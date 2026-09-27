# Marketplace submission candidate

**Title:** `[Plugin]: ProCyclingStats`

**Draft body:** [marketplace-issue.md](marketplace-issue.md)

**Plugin:** `io.github.vip32.procyclingstats`, version `0.8.1`.
**Category:** Widgets. **Tags:** Bar, Quickshell. **Suggested tag:** Sports.

The source repository is public at
[vip32/omarchy-procyclingstats](https://github.com/vip32/omarchy-procyclingstats).
No tag, GitHub release or marketplace issue has been created.

## Contract checked

The live submission form at
[omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace/blob/d654206af8c48fd11344570043e1fde39e40c89b/.github/ISSUE_TEMPLATE/submit-plugin.yml)
was read on 2026-09-27. Its six headings and five checklist statements are preserved.
All attestations are unchecked for the owner to review. Recheck the upstream
form before submitting; the marketplace can change.

## Prepared material

- Root manifest, MIT license, user-facing README and copyable GitHub install,
  update, disable and removal commands.
- Native fictional screenshots, a reproducible demo and asset provenance.
- Dependencies, network/process/file-write disclosures and security reporting guidance.
- Pinned CI actions, portable tests and local native-shell verification.
- [Validation evidence and limitations](validation.md).

The final local candidate SHA, test log and static reports are recorded under
`.git/submission-candidate/` after the preparation commit. That directory is local
release evidence and is not part of the installable checkout.

## Submit the prepared candidate

1. Open [Submit a plugin](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).
   Use the title `[Plugin]: ProCyclingStats`, repository URL above, category
   **Widgets**, tags **Bar** and **Quickshell**, and optional suggested tag **Sports**.
   Copy the maintainer notes from [the prepared body](marketplace-issue.md).
2. Review and personally confirm all five form checklist statements, including
   permission to submit the code and preview assets. They remain unchecked in the
   draft; tooling cannot make these attestations on the owner's behalf.
3. Submit the issue once. The repository URL and plugin ID were checked for
   existing requests on 2026-09-27; none were found. Check again immediately before
   submitting if this draft is used later.
4. Review automated compatibility and security-baseline comments, then address
   any questions in that same issue. Native process execution is documented;
   a review-required disposition alone does not establish a defect.
5. Wait for marketplace maintainer approval and verify the resulting listing.
   Approval applies to an exact commit. Avoid pushing unrelated changes during
   review; later changes need current validation and the marketplace update flow.

The public release preflight passes and GitHub Actions passes all 98 behavioral
tests for the prepared production code. Review the latest commit's CI result
before submission. The current form does not require a GitHub release or version
tag; neither has been created. Listing approval is not a security audit.
