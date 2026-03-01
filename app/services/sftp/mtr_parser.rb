# frozen_string_literal: true

class Sftp::MtrParser
  def initialize(path)
    @path = path
  end

  def parse
    doc = Nokogiri::XML(File.read(@path))
    email_opts = doc.at_xpath('//EmailOptions')

    {
      **job_fields(doc),
      **email_fields(email_opts),
      html_body: decode_body(email_opts)
    }
  end

  private

  def job_fields(doc)
    {
      job_id: text(doc, '//JobID'),
      main_job_id: text(doc, '//MainJobID'),
      batch_id: text(doc, '//BatchID'),
      job_name: text(doc, '//JobName'),
      job_reference: text(doc, '//JobReference'),
      pages: text(doc, '//Pages')&.to_i,
      user_name: text(doc, '//UserName'),
      company_name: text(doc, '//CompanyName'),
      company_id: text(doc, '//CompanyID'),
      department_name: text(doc, '//DepartmentName')
    }
  end

  def email_fields(opts)
    {
      from: opt_text(opts, 'From'),
      to_email: opt_text(opts, 'ToEmail'),
      cc_email: opt_text(opts, 'CCEmail'),
      reply_to: opt_text(opts, 'ReplyTo'),
      subject: opt_text(opts, 'Subject'),
      priority: opt_text(opts, 'Priority'),
      send_date: opt_text(opts, 'SendDate')
    }
  end

  def opt_text(opts, xpath)
    opts&.at_xpath(xpath)&.text
  end

  def decode_body(opts)
    body_b64 = opts&.at_xpath('Body')&.text
    body_b64.present? ? Base64.decode64(body_b64) : ''
  end

  def text(doc, xpath)
    doc.at_xpath(xpath)&.text
  end
end
