# CommMate Custom Extensions

This directory contains CommMate-specific extensions to Chatwoot.

## Structure

- `app/` - Application code (models, controllers, services, jobs, views)
- `config/` - Configuration and routes
- `lib/` - Libraries and utilities
- `spec/` - Tests for custom functionality

## Key Customizations

Document your major customizations here as you add them:

- [ ] Custom authentication flows
- [ ] CommMate-specific integrations
- [ ] Custom reporting and analytics
- [ ] Extended API endpoints
- [ ] Custom frontend components

## Development

See `COMMMATE_EXTENSIONS.md` in the root directory for detailed guidelines on:

- How to extend models, services, and controllers
- Best practices for maintaining upstream compatibility
- Testing strategies
- Troubleshooting common issues

## Getting Started

1. Follow the patterns in `COMMMATE_EXTENSIONS.md`
2. Always use `Custom::` or `Commmate::` namespaces
3. Add tests for your customizations in `spec/`
4. Document any core file modifications

## Testing

Run CommMate-specific tests:

```bash
bundle exec rspec custom/spec/
```

## Important Notes

- This directory is loaded **after** both OSS and Enterprise code
- Extensions here will override Enterprise and OSS implementations
- Always restart the server after modifying custom extensions
- Keep this directory in sync with your CommMate-specific branch

