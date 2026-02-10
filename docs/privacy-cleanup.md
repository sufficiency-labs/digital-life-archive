# Privacy Footprint Reduction

After data archival and verification, procedures for reducing public digital footprint.

## Priority Order

1. **Data brokers** (sell information to any buyer) — highest impact
2. **GitHub email exposure** (commit email public by default)
3. **Social media privacy settings** (reduce visibility)
4. **Account deletion** (archived services)
5. **Ongoing monitoring** (maintain reduced footprint)

## Data Broker Opt-Outs

Sites aggregate public records and sell personal information. Each has opt-out process, typically requiring identity verification.

| Broker | Opt-out URL | Process |
|--------|------------|---------|
| Spokeo | spokeo.com/optout | Search yourself, submit removal |
| BeenVerified | beenverified.com/faq/opt-out | Submit full name + state |
| Whitepages | whitepages.com/suppression-requests | Search and submit removal |
| FastPeopleSearch | fastpeoplesearch.com/removal | Search and click remove |
| TruePeopleSearch | truepeoplesearch.com/removal | Search and submit |
| MyLife | mylife.com/ccpa/index.pubview (CCPA request) | Email privacy@mylife.com |
| Radaris | radaris.com/control/privacy | Request removal |
| Intelius | intelius.com/opt-out | Submit removal form |
| PeopleFinder | peoplefinder.com/optout | Submit removal form |
| USSearch | ussearch.com/opt-out | Submit removal form |

**Note:** Verify after 30 days — some re-list from new data sources.

## GitHub Privacy

1. **Email privacy:** GitHub Settings > Emails > "Keep my email addresses private"
   - Provides `@users.noreply.github.com` address for web commits
   - Existing commits retain real email in git history

2. **Profile cleanup:** Remove real name, location, blog links, employer from profile

3. **Public repositories:** Audit public visibility. Archive unnecessary public repositories:
   ```bash
   gh repo list --visibility public --limit 100
   # For each repository requiring privacy:
   gh repo edit OWNER/REPO --visibility private --accept-visibility-change-consequences
   ```

4. **Public gists:** Delete or convert to secret any gists containing personal information

## Professional Data Aggregators

| Service | Action |
|---------|--------|
| ZoomInfo | community.zoominfo.com/s/privacy-center — request profile removal |
| RocketReach | rocketreach.co/privacy — email privacy@rocketreach.co |
| LinkedIn | Settings > Visibility — restrict profile, disable search indexing |

## Social Media Configuration

| Platform | Key Settings |
|----------|-------------|
| LinkedIn | Visibility settings, disable "People Also Viewed", restrict profile |
| Twitter/X | Protect tweets, remove location, remove employer |
| Instagram | Switch to private account |
| Facebook | Privacy checkup, restrict discoverability, opt out of search engines |
| Goodreads | Profile > Edit > Privacy settings |

## Google Account

Before deletion, archive all data:

1. Google Takeout (takeout.google.com) for Photos, Calendar, Contacts
2. rclone sync for Drive
3. mbsync for Gmail

## Dropbox Account

Before deletion:

1. Verify `rclone sync` completed fully
2. Compare file counts: `rclone size dropbox:` vs `find cloud/dropbox/ -type f | wc -l`
3. Spot-check important files

## Automated Removal Services

Services automating data broker removal if manual opt-outs prove inefficient:

| Service | Cost | Coverage |
|---------|------|----------|
| Incogni | ~$100/year | ~180 brokers |
| DeleteMe | ~$129/year | ~40+ brokers |
| Optery | ~$240/year | ~200+ brokers |

## Ongoing Monitoring

1. **Google Alerts** on personal name: google.com/alerts
2. **HaveIBeenPwned** for breach monitoring: haveibeenpwned.com
3. Re-check data broker sites every 3-6 months
4. Review GitHub commits and repositories periodically

## Limitations

- **Git commit history is permanent.** Email in past commits cannot be removed without history rewriting across all repositories.
- **Public records** (property deeds, voter registration, court records) are government-maintained and generally non-removable.
- **Cached web content** (Google Cache, Wayback Machine) will fade but requires time.
- **Information already possessed** by third parties cannot be controlled — focus on preventing flow to new parties.
