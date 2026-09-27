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
[omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace/blob/de31707ebe3486afff604a380158b511378ed762/.github/ISSUE_TEMPLATE/submit-plugin.yml)
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

## Remaining publication steps

1. Public repository, Issues and private vulnerability reporting are configured.
   Check the latest public commit and its linked validation evidence before submission.
2. Run hosted CI, check public accessibility, and rerun release preflight against
   the final public source. Record the resulting full SHA; any code change needs
   affected checks repeated. The local remove/reinstall lifecycle test has passed.
3. If creating a versioned release, obtain authorization, then create an annotated
   immutable tag and matching release notes. No tag exists for this local candidate.
4. Search the marketplace for the repository and plugin ID to avoid duplicate
   requests. Recheck the current form. Owner confirms every checklist statement,
   including permission for code and preview assets, against the completed draft.
5. Create the approved issue. Listing still requires marketplace maintainer review;
   passing compatibility or static checks does not imply approval.
