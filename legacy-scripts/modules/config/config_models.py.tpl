env = dict(
%{ for model in jsondecode(models) ~}
    ${model.type}=dict(
        maxTokens=${model.maxTokens},
        name="${model.name}",
    ),
%{ endfor ~}
)