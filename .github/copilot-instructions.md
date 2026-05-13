# Copilot instructions for this repository

## Build, test, and lint commands
- Install deps: npm install
- Lint: npm run lint  (runs: eslint **/{aura,lwc}/**/*.js)
- Unit tests (LWC): npm run test:unit  (runs sfdx-lwc-jest)
  - Single test file: npm run test:unit -- path/to/myComponent.test.js
  - By test name: npm run test:unit -- -t "should render correctly"
  - Watch/debug/coverage: npm run test:unit:watch | npm run test:unit:debug | npm run test:unit:coverage
- Prettier format: npm run prettier
- Pre-commit hooks: husky + lint-staged are configured (prettier, eslint, related LWC tests)

## High-level architecture
- Salesforce DX project (sfdx-project.json). Metadata source lives under `force-app` (default packageDirectory).
- Lightning UI code split into LWC and Aura components. LWC files live under LWC folders (lint/jest configs assume `**/lwc/**`), Aura under `**/aura/**`.
- Unit testing uses sfdx-lwc-jest. Jest config extends the official sfdx-lwc-jest config and ignores `.localdevserver`.
- ESLint is configured with Salesforce plugins: separate configs/overrides for Aura, LWC, and test mocks.
- Formatting and hooks: Prettier (including Apex/XML plugins) + husky + lint-staged to auto-run formatting, linting and related tests on staged files.

## Key conventions and repo-specific patterns
- Lint targets: `**/{aura,lwc}/**/*.js`. Run `npm run lint` to validate these.
- LWC test files: rules are relaxed for tests (see eslint override '@lwc/lwc/no-unexpected-wire-adapter-usages' => 'off').
- Jest mock helpers: `**/jest-mocks/**/*.js` have a dedicated ESLint environment (node + jest globals).
- lint-staged behavior:
  - Prettier runs against metadata and code file extensions: *.cls, *.cmp, *.component, *.css, *.html, *.js, *.json, *.md, *.page, *.trigger, *.xml, *.yaml, *.yml
  - Changed LWC JS files trigger eslint and sfdx-lwc-jest with `--findRelatedTests` (fast feedback on related tests).
- sfdx-project.json: check `sourceApiVersion` (65.0) and packageDirectories when planning metadata deployments.
- Use `npx sfdx` or the installed Salesforce CLI for deploy/retrieve/source: commands are outside NPM scripts and rely on SFDX CLI being present.

## Files consulted
- README.md (project overview / Salesforce DX links)
- package.json (scripts, devDependencies, lint-staged)
- eslint.config.js (file-specific ESLint rules for aura, lwc, jest-mocks)
- jest.config.js (sfdx-lwc-jest based config)
- sfdx-project.json (package metadata and API version)

---

Additional: Common SFDX commands and example test/run flags

SFDX CLI (prerequisite): ensure Salesforce CLI is installed and reachable (sfdx --version). Authenticate before running org-targeted commands.

Common SFDX workflows
- Authenticate (web):
  sfdx auth:web:login -a <alias>
- Create a scratch org (if using scratch orgs):
  sfdx force:org:create -s -f config/project-scratch-def.json -a <alias>
- Push source to a scratch org:
  sfdx force:source:push -u <alias>
- Deploy metadata to a non-scratch org (or CI):
  sfdx force:source:deploy -p force-app -u <alias> --checkonly
  (remove --checkonly to perform an actual deploy)
- Retrieve metadata from an org:
  sfdx force:source:retrieve -p force-app -u <alias>
  or by metadata type: sfdx force:source:retrieve -m ApexClass:MyClass -u <alias>
- Open the target org in a browser:
  sfdx force:org:open -u <alias>

sfdx-lwc-jest and test examples
- Run a single test file directly (recommended when iterating on a component):
  npx sfdx-lwc-jest path/to/__tests__/myComponent.test.js
- Run a single test file via the npm script:
  npm run test:unit -- path/to/__tests__/myComponent.test.js
- Run tests matching a test name or pattern:
  npm run test:unit -- -t "should render correctly"
- Run tests related to a changed file (fast):
  npx sfdx-lwc-jest --findRelatedTests path/to/component.js
- Useful flags available: --watch, --coverage, --debug, --bail, --findRelatedTests

If a CI cheat sheet (example deploy commands, validated deploys, or GitHub Actions snippets) or more targeted examples (e.g., retrieving specific metadata types) are wanted, specify which targets to add.