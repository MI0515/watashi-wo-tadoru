module CompanionSelectionData
  private

  def load_companion_selection_data
    @user = current_user

    @personality_type_groups =
      PersonalityType.order(:id).group_by(&:group_code)

    @companions_by_type =
      Companion.includes(personality_type: :monologues)
               .order(:id)
               .group_by(&:personality_type_id)

    @selected_type_id =
      @user.companion&.personality_type_id || @user.personality_type_id

    load_preview_lines
  end

  def load_preview_lines
    @preview_lines = {}

    @companions_by_type.each_value do |companions|
      monologues = companions.first.personality_type.monologues
                             .to_a.sample(companions.length)

      companions.each_with_index do |companion, index|
        @preview_lines[companion.id] = monologues[index]&.content
      end
    end
  end
end
