# EC2 Deploy Scripts — Python Voice Backend

These scripts provision and deploy the Python FastAPI + Whisper voice backend
(`voice-backend/` at repo root, formerly `Dukan_x/backend/`).

## Files

| File | Run when |
|------|----------|
| `ec2-setup.sh` | **Once** on a fresh EC2 instance — installs Python, Node, PM2, nginx |
| `deploy.sh` | Every deploy — clones/pulls repo, installs deps, restarts PM2 |
| `nginx.conf` | Copy to `/etc/nginx/sites-available/dukanx` on the EC2 instance |
| `iam-policy.json` | Attach to the EC2 instance's IAM role for S3 + DynamoDB access |

## Quickstart

```bash
# 1. SSH into EC2
ssh -i ~/.ssh/dukanx.pem ec2-user@<INSTANCE_IP>

# 2. Bootstrap (first time only)
chmod +x ec2-setup.sh && ./ec2-setup.sh

# 3. Deploy
chmod +x deploy.sh && ./deploy.sh
```

## Environment

The voice backend reads from `.env` in the project root on the EC2 instance.
Required keys:
- `WHISPER_MODEL` — e.g. `base` or `small`
- `AWS_REGION`
- `S3_BUCKET` (for audio file storage)

See `docs/ARCHITECTURE.md §4.8` for full context.
