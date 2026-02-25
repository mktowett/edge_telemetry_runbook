# EdgeTelemetry Interactive Deployment Webpage — Project Plan

## Executive Summary
Create a single-file interactive HTML webpage that guides users through the EdgeTelemetry deployment process in a progressive, gamified manner. The site must enable direct GitHub repository downloads and provide step-by-step installation guidance with a focus on simplicity and excellent UX.

---

## Goals & Objectives

### Primary Goals
1. **Simplify Deployment** — Reduce friction in EdgeTelemetry installation by providing an interactive, guided experience
2. **Progressive Disclosure** — Unlock steps sequentially to prevent users from skipping prerequisites
3. **Self-Contained Solution** — Single HTML file, no backend, no build process
4. **GitHub Integration** — Direct download of deployment package from `NCG-Africa/EdgeTelemetryDeployment` master branch

### Success Metrics
- Users can complete deployment without external documentation
- Zero backend dependencies (pure client-side)
- Mobile-responsive (works at 375px minimum width)
- WCAG AA accessibility compliance
- Sub-3-second initial load time

---

## Technical Requirements

### Stack Constraints
- **Framework**: None (Vanilla JavaScript ES6+)
- **Styling**: Tailwind CSS via CDN only
- **Fonts**: Google Fonts (Inter + JetBrains Mono)
- **Icons**: Inline SVG (Heroicons style)
- **State Management**: Single plain object, no persistence
- **Browser Support**: Chrome 90+, Firefox 88+, Safari 14+

### Design System — Material You Dark
- **Base**: `slate-900` background, `slate-800` cards, `slate-700` inputs
- **Primary**: `green-500` (#22c55e) for progress, CTAs, success
- **Accent**: `blue-500` (#3b82f6) for links, secondary actions
- **Semantic**: Amber warnings, red security/danger
- **Spacing**: 8px grid (Tailwind scale only, no arbitrary values)
- **Borders**: `rounded-2xl` cards, `rounded-lg` buttons/inputs, `rounded-full` badges
- **Shadows**: `ring-1 ring-white/5` on cards
- **Transitions**: `transition-all duration-200 ease-in-out` on all interactions

### Layout Constraints
- Max width: `max-w-3xl mx-auto`
- Padding: `px-4 sm:px-6`
- Top padding: `pt-24` (clears fixed progress bar)
- Mobile-first responsive design

---

## User Journey & Features

### Step Flow (Progressive Unlocking)
1. **Prerequisites Check** — System requirements, Ubuntu version, sudo access
2. **Download Package** — GitHub ZIP download with PAT authentication
3. **Environment Configuration** — Interactive `.env` form builder
4. **Server Preparation** — SSH setup, file transfer commands
5. **Deployment Execution** — Docker Compose, Make commands
6. **Service Verification** — Health checks, port validation
7. **Post-Deployment** — Monitoring setup, troubleshooting guide

### Core Features
- **GitHub Download**
  - Fetch latest master branch ZIP from private repo
  - Personal Access Token (PAT) authentication
  - Progress indicator during download
  - Automatic filename with timestamp

- **Interactive .env Builder**
  - Form-based configuration
  - Field validation (ports, IPs, required fields)
  - Real-time preview of generated file
  - One-click copy or download

- **Copy-to-Clipboard**
  - All commands have copy buttons
  - Visual feedback: "Copy" → "✓ Copied!" (2s) → revert
  - Uses `navigator.clipboard` API

- **Progressive Step Unlocking**
  - Steps locked by default: `opacity-40 pointer-events-none`
  - Unlock on "Mark Complete" button click
  - Active step: green left border, full opacity
  - Completed steps: checkmark badge

- **Troubleshooting Panels**
  - Collapsible "Having trouble?" sections
  - Common errors and solutions
  - Links to logs, health checks

---

## Implementation Steps

### Phase 1: Foundation (Day 1)
- [ ] Create clean `index.html` structure
- [ ] Implement Tailwind config with Material You Dark theme
- [ ] Add Google Fonts (Inter, JetBrains Mono)
- [ ] Build fixed progress bar component
- [ ] Set up state management object

### Phase 2: Core Components (Day 1-2)
- [ ] Step card component (locked/active/complete states)
- [ ] Command block with copy button
- [ ] Callout boxes (info, warning, danger, success)
- [ ] Form input components for .env builder
- [ ] Primary CTA buttons (download, complete step)

### Phase 3: GitHub Integration (Day 2)
- [ ] Implement GitHub API ZIP download
  - Endpoint: `https://api.github.com/repos/NCG-Africa/EdgeTelemetryDeployment/zipball/master`
  - Headers: `Authorization: token ${PAT}`, `Accept: application/vnd.github.v3+json`
- [ ] Add PAT configuration section
- [ ] Download progress indicator
- [ ] Error handling (401, 404, network failures)

### Phase 4: Step Content (Day 2-3)
- [ ] **Step 0**: Prerequisites checklist
- [ ] **Step 1**: Download package (GitHub integration)
- [ ] **Step 2**: .env configuration form
- [ ] **Step 3**: Server preparation (SSH, SCP commands)
- [ ] **Step 4**: Deployment commands (Docker, Make)
- [ ] **Step 5**: Health verification
- [ ] **Step 6**: Post-deployment resources

### Phase 5: Interactivity (Day 3)
- [ ] Step unlock logic on "Mark Complete"
- [ ] Progress bar updates (percentage, step counter)
- [ ] Copy button functionality
- [ ] Troubleshooting panel toggles
- [ ] .env form validation and generation
- [ ] Smooth scroll to next step

### Phase 6: Polish & Testing (Day 4)
- [ ] Mobile responsive testing (375px - 1920px)
- [ ] Accessibility audit (ARIA labels, tab order, contrast)
- [ ] Cross-browser testing
- [ ] Error state handling
- [ ] Loading states and animations
- [ ] Final UX polish

---

## Content Structure

### Landing Section
- Hero title: "EdgeTelemetry"
- Subtitle: "Interactive Installation Guide"
- Brief description of what will be deployed
- Architecture overview card (services + ports)

### Step Template
Each step follows this structure:
```
┌─ Step Header ─────────────────────────────────┐
│ [#] Step Title                                │
│     Brief context sentence                    │
└───────────────────────────────────────────────┘
┌─ Step Body ───────────────────────────────────┐
│ • Instructions                                │
│ • Command blocks                              │
│ • Callouts (info/warning/danger)              │
│ • Forms (if applicable)                       │
└───────────────────────────────────────────────┘
┌─ Step Footer ─────────────────────────────────┐
│ [⚠ Having trouble?]    [Mark Complete →]     │
└───────────────────────────────────────────────┘
┌─ Troubleshooting (collapsed) ─────────────────┐
│ Common issues and solutions                   │
└───────────────────────────────────────────────┘
```

---

## Configuration Requirements

### GitHub PAT Setup
- User must provide PAT with `repo` scope
- Stored in JavaScript constant (not persisted)
- Clear instructions on generating PAT
- Security callout about token handling

### Server IP Placeholder
- Default: `<server-ip>` in SCP/SSH commands
- Users replace manually when copying
- Optional: Add form field to auto-replace

---

## Deployment Architecture (Reference)

The guide deploys the following stack:

| Service              | Port | Description                    |
|----------------------|------|--------------------------------|
| Telemetry Collector  | 8001 | Data ingestion API             |
| Telemetry Processor  | 8002 | Data processing service        |
| Dashboard API        | 8003 | Query API with Redis caching   |
| EdgeRum Portal       | 8004 | Web dashboard frontend         |
| Kafka UI             | 8080 | Kafka monitoring interface     |
| Redis                | 6379 | Caching layer                  |
| Kafka + Zookeeper    | Internal | Message broker             |

---

## Non-Goals (Out of Scope)

- ❌ Backend server or API
- ❌ User authentication or session management
- ❌ State persistence (localStorage/sessionStorage)
- ❌ Multi-page navigation
- ❌ Real-time server monitoring
- ❌ Automated deployment execution
- ❌ Build process or bundling

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| GitHub API rate limits | High | Use authenticated requests (5000/hr vs 60/hr) |
| PAT exposure in code | Critical | Clear security warnings, no hardcoding |
| Browser compatibility | Medium | Polyfill clipboard API, test on target browsers |
| Large file download | Low | Show progress, handle timeouts gracefully |
| Mobile UX complexity | Medium | Simplify on small screens, test thoroughly |

---

## Success Criteria

### Functional
- ✅ Downloads ZIP from GitHub master branch
- ✅ Generates valid `.env` file from form
- ✅ All commands copyable with one click
- ✅ Steps unlock sequentially
- ✅ Progress bar updates accurately

### Non-Functional
- ✅ Loads in <3 seconds on 3G
- ✅ Works at 375px viewport width
- ✅ WCAG AA contrast ratios
- ✅ Logical keyboard navigation
- ✅ No console errors

### User Experience
- ✅ Clear visual hierarchy
- ✅ Obvious next action at each step
- ✅ Helpful error messages
- ✅ Smooth animations (no jank)
- ✅ Professional, modern aesthetic

---

## Timeline Estimate

- **Day 1**: Foundation + Core Components (8 hours)
- **Day 2**: GitHub Integration + Step Content (8 hours)
- **Day 3**: Interactivity + Remaining Steps (8 hours)
- **Day 4**: Polish, Testing, Bug Fixes (6 hours)

**Total**: ~30 hours over 4 days

---

## Maintenance & Future Enhancements

### Immediate Post-Launch
- Monitor GitHub API usage
- Collect user feedback on pain points
- Fix critical bugs within 24 hours

### Future Considerations (Not in Scope)
- Analytics integration (privacy-respecting)
- Multi-language support
- Dark/light theme toggle
- Export installation report
- Video walkthrough embeds
- Automated health check pings

---

## Appendix: Key Files

- **Deliverable**: `index.html` (single file, ~1000-1500 lines)
- **Documentation**: `README.md` (usage instructions)
- **Rules**: `.windsurf/rules/edge-wizard.md` (design system)
- **Skills**: `.windsurf/skills/edgeskills/SKILL.md` (component library)

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-23  
**Owner**: EdgeTelemetry Team  
**Status**: Ready for Implementation
