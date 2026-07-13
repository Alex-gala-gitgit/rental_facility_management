import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authorization = request.headers.get('Authorization')
    if (!authorization) throw new Error('Authentication is required.')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const callerClient = createClient(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: authorization } },
    })
    const { data: authData, error: authError } = await callerClient.auth.getUser()
    if (authError || !authData.user) throw new Error('Your owner session is invalid.')

    const adminClient = createClient(supabaseUrl, serviceRoleKey)
    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('role')
      .eq('id', authData.user.id)
      .single()
    if (profileError || profile?.role !== 'owner') {
      return Response.json(
        { error: 'Only a verified property owner can invite tenants.' },
        { status: 403, headers: corsHeaders },
      )
    }

    const body = await request.json()
    const email = String(body.email ?? '').trim().toLowerCase()
    const fullName = String(body.fullName ?? '').trim()
    if (!email.includes('@') || fullName.length < 2) {
      return Response.json(
        { error: 'A valid tenant name and email are required.' },
        { status: 400, headers: corsHeaders },
      )
    }

    const { data: assignment } = await adminClient
      .from('tenant_workspace_snapshots')
      .select('tenant_email')
      .eq('owner_id', authData.user.id)
      .eq('tenant_email', email)
      .maybeSingle()
    if (!assignment) {
      return Response.json(
        { error: 'Create this tenancy with the same email before sending an invitation.' },
        { status: 403, headers: corsHeaders },
      )
    }

    const { error: markError } = await adminClient
      .from('tenant_workspace_snapshots')
      .update({
        invited_at: new Date().toISOString(),
        invitation_sent_by: authData.user.id,
      })
      .eq('owner_id', authData.user.id)
      .eq('tenant_email', email)
    if (markError) throw markError

    const { data, error } = await adminClient.auth.admin.inviteUserByEmail(email, {
      redirectTo: 'https://facility-billing-management.pages.dev/',
      data: { full_name: fullName, role: 'tenant' },
    })
    if (error) {
      await adminClient
        .from('tenant_workspace_snapshots')
        .update({ invited_at: null, invitation_sent_by: null })
        .eq('owner_id', authData.user.id)
        .eq('tenant_email', email)
      throw error
    }

    return Response.json(
      { invited: true, userId: data.user?.id },
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : 'Invitation failed.' },
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
