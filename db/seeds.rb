# Minimal data for local development. Idempotent (find_or_create_by!) so it is
# safe to run repeatedly. Single-tenant: one admin, one project.

admin = User.find_or_create_by!(email: "admin@example.com") { |u| u.role = "admin" }

project = Project.find_or_create_by!(slug: "main-app") { |p| p.name = "Main App" }

locales = %w[ en pt-BR es ].index_with { |code| project.locales.find_or_create_by!(code:) }
common  = project.namespaces.find_or_create_by!(name: "common")
auth    = project.namespaces.find_or_create_by!(name: "auth")

catalog = {
  common => {
    "common.welcome" => { "en" => "Welcome",   "pt-BR" => "Bem-vindo",   "es" => "Bienvenido" },
    "common.goodbye" => { "en" => "Goodbye",    "pt-BR" => "Tchau",       "es" => "Adiós" },
    "common.yes"     => { "en" => "Yes",        "pt-BR" => "Sim",         "es" => "Sí" },
    "common.no"      => { "en" => "No",         "pt-BR" => "Não",         "es" => "No" },
    "common.loading" => { "en" => "Loading…",   "pt-BR" => "Carregando…", "es" => "Cargando…" },
    "common.save"    => { "en" => "Save",       "pt-BR" => "Salvar",      "es" => "Guardar" }
  },
  auth => {
    "auth.signin"   => { "en" => "Sign in",  "pt-BR" => "Entrar", "es" => "Iniciar sesión" },
    "auth.signout"  => { "en" => "Sign out", "pt-BR" => "Sair",   "es" => "Cerrar sesión" },
    "auth.email"    => { "en" => "Email",    "pt-BR" => "E-mail", "es" => "Correo" },
    "auth.password" => { "en" => "Password", "pt-BR" => "Senha",  "es" => "Contraseña" }
  }
}

# Fill every (key, locale); publish every other translation so the dev DB has a
# mix of published and draft state (state = presence of a Publication record).
index = 0
catalog.each do |namespace, keys|
  keys.each do |key_path, values|
    translation_key = namespace.translation_keys.find_or_create_by!(project:, key: key_path)
    values.each do |code, value|
      translation = translation_key.set_translation(locale: locales[code], value:, author: admin)
      translation.publish(by: admin) if index.even? && !translation.published?
      index += 1
    end
  end
end

# A dev API token for exercising the saveMissing endpoint locally (shown once).
unless project.api_tokens.active.exists?
  _token, raw = ApiToken.generate(project:, name: "Local dev", scope: "save_missing", creator: admin)
  puts "\n  saveMissing API token for #{project.slug}: #{raw}\n\n"
end

puts "Seeded #{project.name}: #{project.locales_count} locales, " \
     "#{project.namespaces_count} namespaces, #{project.translation_keys_count} keys."
