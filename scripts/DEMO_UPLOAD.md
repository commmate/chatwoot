# SFTP Demo Batch — Upload Instructions

**Batch**: `scripts/demo_batch/` (50 emails, 50 PDFs, 1 manifest)
**From**: `noreply@ticomailworks.commmate.com`
**Company**: Tico Mail Works (Account 2)
**Server**: `sftp-tmw.commmate.com` (`46.225.58.175`)

---

## Demo Flow

### 1. Upload the batch to the SFTP server

From the **server** (SSH in first):

```bash
ssh tutorialsbot
docker cp /tmp/demo_batch tmw-sftp:/home/sftp_user/campaigns/demo_batch
docker exec tmw-sftp chown -R 1001:1001 /home/sftp_user/campaigns/demo_batch
```

Or from your **local machine** (two steps):

```bash
scp -r scripts/demo_batch tutorialsbot:/tmp/demo_batch
ssh tutorialsbot 'docker cp /tmp/demo_batch tmw-sftp:/home/sftp_user/campaigns/demo_batch && docker exec tmw-sftp chown -R 1001:1001 /home/sftp_user/campaigns/demo_batch'
```

### 2. Wait ~60 seconds

The WatcherJob runs every minute. It will:
1. Detect `demo_batch/` in the SFTP campaigns folder
2. Download all files to a temp directory
3. Match **"Tico Mail Works"** to Account 2
4. Match **`ticomailworks.commmate.com`** to the TMW Email inbox
5. Send all 50 emails with PDF attachments via Resend
6. Create a campaign visible in the dashboard
7. Delete the batch folder from SFTP

### 3. Check results

```bash
ssh tutorialsbot 'docker exec tmw-sftp ls /home/sftp_user/campaigns/'
```

Should be empty (folder cleaned up after processing).

---

## Re-run the demo (upload again)

The batch folder is deleted after processing, so you can re-upload anytime:

```bash
ssh tutorialsbot 'docker cp /tmp/demo_batch tmw-sftp:/home/sftp_user/campaigns/demo_batch && docker exec tmw-sftp chown -R 1001:1001 /home/sftp_user/campaigns/demo_batch'
```

Each upload creates a new campaign in the dashboard.

---

## Regenerate the batch (if needed)

```bash
cd scripts
source .venv/bin/activate
python generate_demo_batch.py
scp -r demo_batch tutorialsbot:/tmp/demo_batch
```

---

## Notes

- **Rate limit**: Resend free tier allows 2 requests/second. Some emails may
  fail with 429 errors. A paid plan has higher limits. The delivery report
  tracks successes and failures accurately.
- **Recipients**: All 50 emails go to `schimuneck.matias@gmail.com` (via Gmail
  `+` aliases), so they all land in one inbox for easy verification.
- **PDF attachments**: Each email has a unique, non-empty PDF document (~2.7KB)
  with professional content matching the email scenario.
- **5 business scenarios** rotate across the 50 emails: Hospital Billing,
  Insurance, Utility Bills, Banking Statements, Government Notices.

## Batch contents

```
demo_batch/
  email_001.mtr  email_001.pdf    (Hospital Billing — María García López)
  email_002.mtr  email_002.pdf    (Insurance — Carlos Rodríguez Mora)
  ...
  email_050.mtr  email_050.pdf    (Government — Fabián Arguello Venegas)
  Email.tkt                        (pipe-delimited manifest)
```
