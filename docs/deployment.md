# 🚀 DadaKnows Deployment Guide

## Edge Functions Architecture

```
supabase/
├── functions/
│   ├── ask-dada/
│   │   ├── index.ts          # Core AI Q&A function
│   │   └── deno.json         # Deno configuration
│   └── _shared/
│       ├── cors.ts           # CORS handling
│       ├── gemini.ts         # Gemini API client
│       └── prompts.ts        # Prompt templates
├── config.toml               # Supabase project config
└── migrations/
    └── 001_create_core_tables.sql
```

## Quick Deployment

```bash
# One-click deployment
./deploy-supabase.sh
```

## Manual Deployment

```bash
# 1. Install Supabase CLI
brew install supabase/tap/supabase

# 2. Login
supabase login

# 3. Link project
cd supabase
supabase link --project-ref YOUR_PROJECT_REF

# 4. Deploy functions
supabase functions deploy ask-dada --no-verify-jwt

# 5. Set environment variables
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GEMINI_API_KEY` | Google Gemini API key | Yes |
| `SUPABASE_URL` | Your Supabase project URL | Yes |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | Yes |

## Testing Deployment

```bash
# Test the ask-dada function
./test-ask-dada.sh

# Or manually test
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/ask-dada' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"question": "What is the sun?", "childAge": 5, "language": "zh"}'
```

## iOS App Configuration

Update `DadaKnows/Core/Config.swift`:

```swift
struct Config {
    static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
    static let supabaseAnonKey = "YOUR_ANON_KEY"
    // ... other config
}
```

## Production Checklist

- [ ] Supabase project created and configured
- [ ] Edge Functions deployed successfully  
- [ ] Environment variables set
- [ ] Database tables created (via migrations)
- [ ] iOS app config updated
- [ ] Authentication configured
- [ ] RLS policies enabled
- [ ] Monitoring and logging set up

## Monitoring

- **Supabase Dashboard**: Monitor function invocations, errors, and performance
- **Edge Function Logs**: `supabase functions logs ask-dada`
- **Database Monitoring**: Track query performance and usage

## Scaling Considerations

- Edge Functions auto-scale based on demand
- Database connection pooling handled by Supabase
- Consider implementing rate limiting for production
- Monitor Gemini API usage and quotas

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Function deployment fails | Check Deno.json syntax and dependencies |
| CORS errors | Verify CORS configuration in _shared/cors.ts |
| API key errors | Ensure GEMINI_API_KEY is set correctly |
| Database connection issues | Check RLS policies and authentication |

For more help, see the [Supabase Edge Functions documentation](https://supabase.com/docs/guides/functions).
