module RedmineRate
  module Hooks
    class ProjectHook < Redmine::Hook::ViewListener
      def protect_against_forgery?
        false
      end

      # Renders an additional table header to the membership setting
      #
      # Context:
      # * project: Current project
      #
      def view_projects_settings_members_table_header(context = {})
        return '' unless User.current.allowed_to?(:view_rate, context[:project]) || User.current.admin?
        "<th>#{l(:label_rate)} #{currency_name}</td>"
      end

      # Renders an AJAX from to update the member's billing rate
      #
      # Context:
      # * project: Current project
      # * member: Current Member record
      #
      # TODO: Move to a view
      def view_projects_settings_members_table_row(context = {})
        member = context[:member]
        project = context[:project]

        return '' unless User.current.allowed_to?(:view_rate, project) || User.current.admin?

        # Groups cannot have a rate
        return content_tag(:td, '') if member.principal.is_a? Group
        rate = Rate.for(member.principal, project)

        content = ''.html_safe

        if rate.nil? || rate.default?
          if rate && rate.default?
            content << "<em>#{number_to_currency(rate.amount)}</em> ".html_safe
          end

          if User.current.admin?

          url = {
            controller: 'rates',
            action: 'create',
            method: :post,
            protocol: Setting.protocol,
            host: Setting.host_name
          }
          # Build a form_remote_tag by hand since this isn't in the scope of a controller
          # and url_rewriter doesn't like that fact.
          form = form_tag url, remote: true

          form << text_field(:rate, :amount)
          form << hidden_field(:rate, :date_in_effect, value: Time.zone.today.to_s)
          form << hidden_field(:rate, :project_id, value: project.id)
          form << hidden_field(:rate, :user_id, value: member.user.id)
          form << hidden_field_tag('back_url', url_for(controller: 'projects',
                                                       action: 'settings',
                                                       id: project,
                                                       tab: 'members',
                                                       protocol: Setting.protocol,
                                                       host: Setting.host_name))

          form << submit_tag(l(:rate_label_set_rate), class: 'small')
          form << '</form>'.html_safe

          content << form
          end
        else
          if User.current.admin?
            content << content_tag(:strong, link_to(show_number_with_currency(rate.amount),
                                                    controller: 'users',
                                                    action: 'edit',
                                                    id: member.user,
                                                    tab: 'rates',
                                                    protocol: Setting.protocol,
                                                    host: Setting.host_name))
          else
            content << content_tag(:strong, number_to_currency(rate.amount))
          end
        end
        content_tag(:td, content, align: 'left', id: "rate_#{project.id}_#{member.user.id}").html_safe
      end

      def model_project_copy_before_save(context = {})
        source = context[:source_project]
        destination = context[:destination_project]

        Rate.where(project_id: source.id).each do |source_rate|
          destination_rate = Rate.new

          destination_rate.attributes = source_rate.attributes.except('project_id')
          destination_rate.project = destination
          destination_rate.save # Need to save here because there is no relation on project to rate
        end
      end
    end
  end
end
