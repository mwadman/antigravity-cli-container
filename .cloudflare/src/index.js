/**
 * Cloudflare Worker for antigravity-cli-container
 * 
 * Periodically checks GitHub releases for google-antigravity/antigravity-cli.
 * When a new release is detected, it dispatches the GitHub Action workflow:
 * mwadman/antigravity-cli-container/.github/workflows/publish.yml
 */

export default {
  // Cron trigger execution
  async scheduled(event, env, ctx) {
    ctx.waitUntil(checkAndDispatch(env));
  },

  // Manual trigger / status endpoint via browser or curl
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === '/test' || url.pathname === '/run') {
      const force = url.searchParams.get('force') === 'true';
      const result = await checkAndDispatch(env, force);
      return new Response(JSON.stringify(result, null, 2), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const lastSeen = env.WORKFLOW_STATE ? await env.WORKFLOW_STATE.get('last_antigravity_version') : null;
    return new Response(
      `Antigravity CLI Release Watcher Worker\n\nLast processed version: ${lastSeen || 'None'}\n\nEndpoints:\n- /test : Check status\n- /run?force=true : Force trigger GitHub Action dispatch\n`,
      { headers: { 'Content-Type': 'text/plain' } }
    );
  }
};

async function checkAndDispatch(env, force = false) {
  const targetRepo = 'google-antigravity/antigravity-cli';
  const myRepo = 'mwadman/antigravity-cli-container';

  try {
    // 1. Fetch latest release from upstream repo
    const releaseRes = await fetch(`https://api.github.com/repos/${targetRepo}/releases/latest`, {
      headers: {
        'User-Agent': 'Cloudflare-Worker-Antigravity-Watcher',
        'Accept': 'application/vnd.github.v3+json'
      }
    });

    if (!releaseRes.ok) {
      console.error(`Failed to fetch latest release: ${releaseRes.status}`);
      return { status: 'error', error: `GitHub API returned ${releaseRes.status}` };
    }

    const release = await releaseRes.json();
    const latestVersion = release.tag_name || release.name;

    // 2. Check last processed version in KV
    const lastSeen = env.WORKFLOW_STATE ? await env.WORKFLOW_STATE.get('last_antigravity_version') : null;
    console.log(`Latest upstream version: ${latestVersion}, Last processed: ${lastSeen}`);

    if (force || lastSeen !== latestVersion) {
      console.log(`Triggering build for version: ${latestVersion}`);

      // 3. Dispatch GitHub Action workflow in mwadman/antigravity-cli-container
      const dispatchRes = await fetch(`https://api.github.com/repos/${myRepo}/actions/workflows/publish.yml/dispatches`, {
        method: 'POST',
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': `Bearer ${env.GITHUB_PAT}`,
          'User-Agent': 'Cloudflare-Worker-Antigravity-Watcher'
        },
        body: JSON.stringify({
          ref: 'main',
          inputs: {
            version: latestVersion
          }
        })
      });

      if (!dispatchRes.ok) {
        const errorText = await dispatchRes.text();
        console.error(`Failed to dispatch workflow: ${dispatchRes.status} ${errorText}`);
        return { status: 'dispatch_failed', code: dispatchRes.status, error: errorText };
      }

      // 4. Update KV state
      if (env.WORKFLOW_STATE) {
        await env.WORKFLOW_STATE.put('last_antigravity_version', latestVersion);
      }

      return { status: 'dispatched', version: latestVersion, triggeredAt: new Date().toISOString() };
    }

    return { status: 'no_change', version: latestVersion, lastSeen };
  } catch (err) {
    console.error('Error during checkAndDispatch:', err);
    return { status: 'error', error: err.message };
  }
}
