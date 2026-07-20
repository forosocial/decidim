# scripts/rejected_proposals.rb
# ejecutar con:
# bundle exec rails runner scripts/rejected_proposals.rb

Decidim::Amendment.where(state: "rejected").includes(:amender, :amendable, :emendation).each do |amendment|
  # Autor de la enmienda
  amender_name = amendment.amender&.name || "Desconocido"
  amender_id = amendment.amender&.id
  
  # Propuesta original
  original_proposal = amendment.amendable
  original_title = original_proposal&.title || "Sin título"
  
  # Fecha de creación de la enmienda
  created_date = amendment.created_at
  
  # Fecha de la notificación (cuando se cambió el estado a rejected/accepted)
  # Esta es la fecha en que se desencadenaron las notificaciones
  notification_date = amendment.updated_at
  
  # Evaluador (autor de la propuesta original)
  evaluator = original_proposal&.authors&.first
  evaluator_name = evaluator&.name || "Desconocido"
  evaluator_id = evaluator&.id
  
  # --- Usuarios notificados ---
  # Según el código de Decidim, cuando se rechaza una enmienda,
  # los notificados son: autores de la enmienda + autores de la propuesta original [citation:5][citation:8]
  emendation_authors = amendment.emendation&.authors || []
  amendable_authors = original_proposal&.authors || []
  
  # Usuarios afectados (reciben notificación)
  affected_users = (emendation_authors + amendable_authors).uniq
  
  # Seguidores de la enmienda y de la propuesta original (también reciben notificación)
  # Nota: los seguidores se obtienen a través de las relaciones, pero no están disponibles
  # directamente desde el modelo Amendment en una consulta simple
  
  puts "--------------------------------------------------"
  puts "ID de la Enmienda: #{amendment.id}"
  puts "Estado: #{amendment.state}"
  puts "Fecha de creación: #{created_date}"
  puts "Fecha de notificación (cambio de estado): #{notification_date}"
  puts "Autor de la enmienda: #{amender_name} (ID: #{amender_id})"
  puts "Propuesta original: #{original_title}"
  puts "Evaluador: #{evaluator_name} (ID: #{evaluator_id})"
  puts "IDs de usuarios notificados (autores): #{affected_users.map(&:id).join(', ')}"
  

  def inspect_sidekiq_jobs_for_rejected_amendment(amendment)
    puts "\n" + "="*60
    puts "🔍 Buscando trabajos de Sidekiq para ENMIENDA RECHAZADA ##{amendment.id}"
    puts "="*60
    
    # Solo procesamos si la enmienda está rechazada
    return unless amendment.state == "rejected"
    
    # Obtener IDs relevantes
    amendment_id = amendment.id
    emendation_id = amendment.emendation&.id
    amendable_id = amendment.amendable&.id
    
    found_events = []
    found_mailers = []
    
    # 1. Buscar en cola 'events' (trabajos de EventPublisherJob)
    events_queue = Sidekiq::Queue.new('events')
    events_queue.each do |job|
        job_args = job['args']
        next unless job_args.is_a?(Array) && job_args.any?
        
        # Extraer los argumentos del trabajo
        first_arg = job_args.first
        if first_arg.is_a?(Hash) && first_arg['arguments'].is_a?(Array)
        # Formato: {"job_class"=>"Decidim::EventPublisherJob", "arguments"=>[...]}
        event_name = first_arg['arguments']&.first
        event_data = first_arg['arguments']&.second
        
        # Verificar que sea un evento de enmienda rechazada
        next unless event_name.to_s.include?("amendment_rejected")
        
        # Extraer el ID del recurso (propuesta) del evento
        resource_globalid = event_data&.dig('resource', '_aj_globalid')
        next unless resource_globalid
        
        # Extraer el ID del recurso del globalid
        resource_id = resource_globalid.to_s.scan(/Proposal\/(\d+)/).flatten.first
        
        # Verificar que el recurso sea la propuesta original o la enmienda
        if resource_id && (resource_id.to_i == amendable_id || resource_id.to_i == emendation_id)
            found_events << job
            puts "✅ EVENTO DE RECHAZO ENCONTRADO en cola 'events':"
            puts "  - JID: #{job['jid']}"
            puts "  - Fecha encolado: #{Time.at(job['enqueued_at']) if job['enqueued_at']}"
            puts "  - Evento: #{event_name}"
            puts "  - Recurso (propuesta): Proposal ##{resource_id}"
            puts "  - Usuarios afectados:"
            
            # Mostrar los usuarios afectados
            affected_users = event_data&.dig('affected_users') || []
            affected_users.each do |user_data|
            user_id = user_data['_aj_globalid'].to_s.scan(/User\/(\d+)/).flatten.first
            user_name = Decidim::User.find(user_id).name
            puts "    - User ##{user_id}  #{user_name}"
            end
        end
        end
    end
    
    # 2. Buscar en cola 'mailers' (trabajos de envío de emails)
    mailers_queue = Sidekiq::Queue.new('mailers')
    mailers_queue.each do |job|
        job_args = job['args']
        next unless job_args.is_a?(Array) && job_args.any?
        
        first_arg = job_args.first
        if first_arg.is_a?(Hash) && first_arg['arguments'].is_a?(Array)
        # Extraer argumentos del trabajo de email
        mailer_args = first_arg['arguments']
        mailer_class = mailer_args&.first
        
        # Buscar trabajos de NotificationMailer (envío de notificaciones por email)
        next unless mailer_class.to_s.include?("NotificationMailer")
        
        # Extraer información del evento
        event_data = mailer_args&.second
        if event_data.is_a?(Hash) && event_data['event_name'].to_s.include?("amendment_rejected")
            # Verificar que el evento esté relacionado con esta enmienda
            if event_data['resource'].to_s.include?(amendment_id.to_s) || 
            event_data['resource'].to_s.include?(emendation_id.to_s) ||
            event_data['resource'].to_s.include?(amendable_id.to_s)
            
            found_mailers << job
            puts "✅ EMAIL DE RECHAZO ENCONTRADO en cola 'mailers':"
            puts "  - JID: #{job['jid']}"
            puts "  - Fecha encolado: #{Time.at(job['enqueued_at']) if job['enqueued_at']}"
            puts "  - Para usuario: User ##{event_data['user_id']}"
            puts "  - Evento: #{event_data['event_name']}"
            puts "  - Email: #{event_data['user_email']}" if event_data['user_email']
            puts "  - Asunto: #{event_data['subject']}" if event_data['subject']
            end
        end
        end
    end
    
    # 3. Buscar en trabajos programados (Scheduled)
    puts "\n--- Buscando en trabajos programados ---"
    scheduled = Sidekiq::ScheduledSet.new
    scheduled.each do |job|
        job_args = job['args'].to_s
        if job_args.include?("amendment_rejected") && 
        (job_args.include?("Proposal/#{amendable_id}") || job_args.include?("Proposal/#{emendation_id}"))
        puts "⚠️ Trabajo programado (rejected) encontrado:"
        puts "  - JID: #{job['jid']}"
        puts "  - Fecha programada: #{Time.at(job['at']) if job['at']}"
        end
    end
    
    # Resumen
    puts "\n" + "-"*60
    puts "📊 Resumen para enmienda ##{amendment_id}:"
    puts "  - Eventos en cola 'events': #{found_events.count}"
    puts "  - Emails en cola 'mailers': #{found_mailers.count}"
    
    if found_events.empty? && found_mailers.empty?
        puts "  ℹ️ No se encontraron trabajos de rechazo en Sidekiq para esta enmienda."
        puts "     Puede que ya hayan sido procesados o que el historial no los conserve."
    end
    puts "="*60
    end
  inspect_sidekiq_jobs_for_rejected_amendment(amendment)
end
