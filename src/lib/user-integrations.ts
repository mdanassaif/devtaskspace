import { getSupabaseServerClient } from '@/lib/supabase-server';
import { decryptSecret, encryptSecret } from '@/lib/secrets';

export type IntegrationSettings = {
  resendApiKey: string;
  alertEmail: string;
  fromEmail: string;
};

export async function getUserIntegrationSettings(username: string): Promise<IntegrationSettings> {
  const supabase = getSupabaseServerClient();
  const { data, error } = await supabase
    .from('integration_settings')
    .select('*')
    .eq('user_id', username)
    .maybeSingle();

  if (error || !data) {
    return {
      resendApiKey: '',
      alertEmail: '',
      fromEmail: '',
    };
  }

  return {
    resendApiKey: decryptSecret(data.resend_api_key_enc),
    alertEmail: decryptSecret(data.alert_email_enc),
    fromEmail: decryptSecret(data.from_email_enc),
  };
}

export async function saveUserIntegrationSettings(username: string, settings: IntegrationSettings) {
  const supabase = getSupabaseServerClient();
  const { error } = await supabase.from('integration_settings').upsert(
    {
      user_id: username,
      // Clear any legacy AI key stored for this user.
      anthropic_api_key_enc: encryptSecret(''),
      resend_api_key_enc: encryptSecret(settings.resendApiKey),
      alert_email_enc: encryptSecret(settings.alertEmail),
      from_email_enc: encryptSecret(settings.fromEmail),
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' }
  );

  if (error) throw new Error(error.message);
}

