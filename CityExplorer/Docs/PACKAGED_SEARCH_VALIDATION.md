# Packaged address flow — 2026-10-01

Visual upgrades remain paused. This is a search/input repair milestone, not an end-to-end acceptance claim.

## Confirmed defects and repairs

The original text field had no Enter/commit binding. Input mode was applied on Home without an explicit field focus target when changing screens. Selection had no change binding or Next enable/disable state; the first result was selected implicitly. The initial widget tree was also rebuilt again during NativeConstruct.

ExplorerAppWidget now binds Enter and query changes, uses readable input text, invalidates obsolete searches/selections, displays result feedback, and enables Next only for a selected valid result. Resolving validates a safe road spawn before storing the selected point and opening vehicle selection.

ExplorerPlayerController configures every screen transition: UIOnly with field/button focus for menus, GameAndUI with viewport focus for driving, visible cursor, no mouse capture or lock, and cleared vehicle input in menus. Pause/resume restores the appropriate mode. DefaultEngine.ini enables high-DPI game UI to agree with the macOS Retina bundle configuration; a Retina-specific mouse defect has not yet been proven.

The search subsystem ensures city data is loaded, cancels stale requests on edits, and logs offline result counts. No API key is required for recorded addresses. The original packaged database was present and returned addresses; missing data or credentials is not established as the cause.

## Actual packaged checks

- Apple Silicon Development executable compiled successfully with UE 5.8.3 / Xcode 27.
- Cook, staging, signing, and strict deep signature verification passed.
- Updated bundle installed at `/Applications/City Explorer Unreal.app`. Prior versions retained in temporary backup locations; Godot application unchanged.
- In the installed candidate, keyboard navigation reached address entry; typing `Carrer de Mallorca 494` and pressing Enter logged submitted length=22 and displayed count=3. Earlier original-package testing also returned a Sagrada Familia address through the Search button via keyboard.
- Automated mouse clicks did not establish successful button activation. The final diagnostic build records Slate pointer hit paths in Development builds without consuming events. Exact chosen coordinates are logged only with `-CityExplorerInputTrace`; ordinary logs use counts and state flags.
- Before the final installed diagnostic build could be tested, the Mac locked and computer control explicitly reported it could not unlock it.

## Acceptance still pending

Physical mouse Explore → Barcelona → focus/type address → Search/Enter → open results → select result → Next → Start exploring; prove stored point and car/world spawn at that safe road. Also verify no-results feedback, edited-query invalidation, and pause/resume input. Do not mark the blocker resolved or restart visual work until these pass in the installed app.


## October 3 follow-up

Installed keyboard search → selection → Next → car/world startup now passes for Mallorca and Balmes. Pause, settings and navigation buttons also passed. See [the updated checklist](PLAYABILITY_CHECK_2026-10-03.md) for repairs, test boundaries and remaining physical mouse coverage. The historical October 1 pending results above are retained as the original record.
