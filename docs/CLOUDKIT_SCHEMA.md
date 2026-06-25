# CloudKit Schema — Camera Data

The sync engine uses a custom `LogEntry` record type in container `iCloud.com.visionarypov.cameradata`.

## First launch

In the **Development** environment, CloudKit auto-creates record types when the app **saves** the first record. Inbound **queries** fail until that happens — the app now treats a missing `LogEntry` type as an empty remote store during bootstrap.

Log one take on device; the schema is created on first push.

## Optional: define schema in CloudKit Dashboard

1. Open [CloudKit Dashboard](https://icloud.developer.apple.com/)
2. Select container `iCloud.com.visionarypov.cameradata`
3. **Development** environment → **Schema** → **Record Types** → **+**
4. Name: `LogEntry`
5. Add fields:

| Field | Type |
|-------|------|
| scene | String |
| take | Int64 |
| lens | String |
| iso | Int64 |
| syncVersion | Int64 |
| productionCode | String |

6. **Deploy Schema Changes** to Development

Also add `Production` (fields: `name`, `code`, `directorName`, `dpName`, `episodeOrProductionNumber`) if using share creation.