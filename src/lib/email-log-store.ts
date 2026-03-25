export type EmailLog = {
  id: string;
  to: string;
  subject: string;
  text: string;
  status: 'sent' | 'failed';
  sentAt: string;
  resendId?: string;
};

const emailLogs: EmailLog[] = [];

export function addEmailLog(log: EmailLog) {
  emailLogs.unshift(log);
}

export function listEmailLogs() {
  return emailLogs;
}

export function findEmailLogByResendId(resendId: string) {
  return emailLogs.find(log => log.resendId === resendId);
}

