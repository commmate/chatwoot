#!/bin/bash
# SFTP campaign edge-case tests on production.
# Run on server: bash /tmp/run_sftp_edge_tests.sh
# Requires: docker, access to commmate-sftp and sidekiq containers.

set -e
BASE=/tmp/sftp_edge_tests
SFTP_CAMPAIGNS=/home/sftp_user/campaigns

# Base64 of "<p>Test body</p>"
B64_BODY="PHA+VGVzdCBib2R5PC9wPg=="

mkdir -p "$BASE"
cd "$BASE"

# 1. Valid batch — CommMate + noreply@commmate.com (inbox 22, SFTP enabled)
mkdir -p edge_valid
cat > edge_valid/email1.mtr << 'MTR'
<?xml version="1.0"?>
<Root>
  <JobID>edge-valid-1</JobID>
  <BatchID>edge-valid-batch</BatchID>
  <CompanyName>CommMate</CompanyName>
  <EmailOptions>
    <From>noreply@commmate.com</From>
    <ToEmail>schimuneck.matias@gmail.com</ToEmail>
    <Subject>Edge test: valid batch</Subject>
    <Body>PHA+VGVzdCBib2R5PC9wPg==</Body>
  </EmailOptions>
</Root>
MTR
cat > edge_valid/email2.mtr << 'MTR'
<?xml version="1.0"?>
<Root>
  <JobID>edge-valid-2</JobID>
  <BatchID>edge-valid-batch</BatchID>
  <CompanyName>CommMate</CompanyName>
  <EmailOptions>
    <From>noreply@commmate.com</From>
    <ToEmail>apvtrevisan@gmail.com</ToEmail>
    <Subject>Edge test: valid batch</Subject>
    <Body>PHA+VGVzdCBib2R5PC9wPg==</Body>
  </EmailOptions>
</Root>
MTR
echo "PDF placeholder" > edge_valid/email1.pdf
echo "PDF placeholder" > edge_valid/email2.pdf

# 2. No account — unknown company name
mkdir -p edge_no_account
cat > edge_no_account/email1.mtr << 'MTR'
<?xml version="1.0"?>
<Root>
  <JobID>edge-no-acc-1</JobID>
  <BatchID>edge-no-acc-batch</BatchID>
  <CompanyName>NonExistentCompanyXYZ</CompanyName>
  <EmailOptions>
    <From>noreply@commmate.com</From>
    <ToEmail>schimuneck.matias@gmail.com</ToEmail>
    <Subject>Edge test: no account</Subject>
    <Body>PHA+VGVzdCBib2R5PC9wPg==</Body>
  </EmailOptions>
</Root>
MTR

# 3. No inbox — wrong domain
mkdir -p edge_no_inbox
cat > edge_no_inbox/email1.mtr << 'MTR'
<?xml version="1.0"?>
<Root>
  <JobID>edge-no-inbox-1</JobID>
  <BatchID>edge-no-inbox-batch</BatchID>
  <CompanyName>CommMate</CompanyName>
  <EmailOptions>
    <From>noreply@otherdomain.com</From>
    <ToEmail>schimuneck.matias@gmail.com</ToEmail>
    <Subject>Edge test: no inbox</Subject>
    <Body>PHA+VGVzdCBib2R5PC9wPg==</Body>
  </EmailOptions>
</Root>
MTR

# 4. SFTP disabled — test@commmate.com (inbox 23 has sftp_campaigns_enabled false)
mkdir -p edge_sftp_disabled
cat > edge_sftp_disabled/email1.mtr << 'MTR'
<?xml version="1.0"?>
<Root>
  <JobID>edge-sftp-disabled-1</JobID>
  <BatchID>edge-sftp-disabled-batch</BatchID>
  <CompanyName>CommMate</CompanyName>
  <EmailOptions>
    <From>test@commmate.com</From>
    <ToEmail>schimuneck.matias@gmail.com</ToEmail>
    <Subject>Edge test: sftp disabled</Subject>
    <Body>PHA+VGVzdCBib2R5PC9wPg==</Body>
  </EmailOptions>
</Root>
MTR

# 5. No MTR files — only pdf/tkt
mkdir -p edge_no_mtr
echo "dummy" > edge_no_mtr/file1.pdf
echo "dummy" > edge_no_mtr/file2.tkt

# 6. Malformed XML
mkdir -p edge_bad_xml
echo '<broken xml no closing tag' > edge_bad_xml/email1.mtr

echo "Uploading all batch folders to SFTP container..."
for dir in edge_valid edge_no_account edge_no_inbox edge_sftp_disabled edge_no_mtr edge_bad_xml; do
  docker exec commmate-sftp mkdir -p "$SFTP_CAMPAIGNS/$dir"
  docker cp "$BASE/$dir/." "commmate-sftp:$SFTP_CAMPAIGNS/$dir/"
  docker exec commmate-sftp chown -R 1001:1001 "$SFTP_CAMPAIGNS/$dir"
done

echo "Triggering WatcherJob..."
docker exec sidekiq bundle exec rails runner "Sftp::WatcherJob.perform_later" 2>&1 | tail -2

echo "Waiting 90s for jobs to process..."
sleep 90

echo "=== SFTP campaigns dir (should be empty) ==="
docker exec commmate-sftp ls -la "$SFTP_CAMPAIGNS/" 2>&1 || true

echo "=== Recent Sidekiq SFTP/campaign logs ==="
docker logs sidekiq 2>&1 | grep -E "ProcessBatchJob|WatcherJob|invalid_upload|no_account|no_inbox|SftpCampaignMailer|SFTP" | tail -50

echo "=== Latest SFTP campaigns (expect 1 new: edge_valid) ==="
docker exec chatwoot bundle exec rails runner "
  Campaign.where(\"title LIKE ?\", \"SFTP%\").order(created_at: :desc).limit(5).each do |c|
    puts \"#{c.id} #{c.title} #{c.created_at}\"
  end
" 2>&1 | grep -E "^[0-9]+|SFTP" || true

echo "Done."
